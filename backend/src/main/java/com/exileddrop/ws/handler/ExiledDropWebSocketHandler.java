package com.exileddrop.ws.handler;

import com.exileddrop.chat.entity.Message;
import com.exileddrop.chat.repository.ConversationRepository;
import com.exileddrop.chat.service.ChatService;
import com.exileddrop.config.PushService;
import com.exileddrop.ws.dto.WsMessage;
import com.exileddrop.ws.dto.WsMessage.*;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.*;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.util.List;
import java.util.UUID;

@Slf4j
@Component
@RequiredArgsConstructor
public class ExiledDropWebSocketHandler extends TextWebSocketHandler {

    private final ObjectMapper objectMapper;
    private final PresenceTracker presenceTracker;
    private final ChatService chatService;
    private final ConversationRepository conversationRepository;
    private final PushService pushService;

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        UUID userId = getUserId(session);
        String username = getUsername(session);

        presenceTracker.userConnected(userId, session);
        log.info("User connected: {} ({})", username, userId);

        broadcastPresence(userId, username, "ONLINE");
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        UUID userId = presenceTracker.userDisconnected(session);
        if (userId != null) {
            String username = getUsername(session);
            log.info("User disconnected: {} ({})", username, userId);
            broadcastPresence(userId, username, "OFFLINE");
        }
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage textMessage) {
        UUID senderId = getUserId(session);
        String senderName = getUsername(session);

        try {
            JsonNode root = objectMapper.readTree(textMessage.getPayload());
            String type = root.path("type").asText();

            switch (type) {
                case "chat.message" -> handleChatMessage(senderId, senderName, root);
                case "call.offer" -> handleCallOffer(senderId, senderName, root);
                case "call.answer" -> handleCallAnswer(senderId, root);
                case "call.ice" -> handleCallIce(senderId, root);
                case "typing.start", "typing.stop" -> handleTyping(senderId, senderName, type, root);
                case "message.read" -> handleMessageRead(senderId, senderName, root);
                case "call.hangup" -> handleCallHangup(senderId, root);
                case "call.reject" -> handleCallReject(senderId, root);
                default -> sendError(session, "Unknown message type: " + type);
            }
        } catch (Exception e) {
            log.error("Error handling WebSocket message from {}: {}", senderId, e.getMessage(), e);
            sendError(session, "Invalid message format");
        }
    }

    // ── Chat ──

    private void handleChatMessage(UUID senderId, String senderName, JsonNode root) {
        UUID conversationId = UUID.fromString(root.path("conversationId").asText());
        String content = root.path("content").asText();

        if (content == null || content.isBlank()) return;

        Message saved = chatService.saveMessage(conversationId, senderId, content);

        ChatMessageDelivery delivery = new ChatMessageDelivery(
                saved.getId(),
                conversationId,
                senderId,
                senderName,
                content,
                saved.getCreatedAt()
        );

        sendToConversationParticipants(conversationId, delivery);

        // Push notification to offline participants
        List<UUID> participantIds = conversationRepository.findParticipantIds(conversationId);
        for (UUID pid : participantIds) {
            if (!pid.equals(senderId) && !presenceTracker.isOnline(pid)) {
                pushService.sendMessageNotification(pid, senderName, content);
            }
        }
    }

    // ── Call Signaling ──

    private void handleCallOffer(UUID senderId, String senderName, JsonNode root) {
        UUID targetId = UUID.fromString(root.path("targetUserId").asText());
        String sdp = root.path("sdp").asText();
        String callType = root.path("callType").asText("AUDIO");

        log.info("Call offer from {} to {} (type: {}, target online: {})",
                senderName, targetId, callType, presenceTracker.isOnline(targetId));

        sendToUser(targetId, new CallOfferDelivery(senderId, senderName, sdp, callType));

        if (!presenceTracker.isOnline(targetId)) {
            pushService.sendCallNotification(targetId, senderName, callType);
        }
    }

    private void handleCallAnswer(UUID senderId, JsonNode root) {
        UUID targetId = UUID.fromString(root.path("targetUserId").asText());
        String sdp = root.path("sdp").asText();

        log.info("Call answer from {} to {} (target online: {})",
                senderId, targetId, presenceTracker.isOnline(targetId));

        sendToUser(targetId, new CallAnswerDelivery(senderId, sdp));
    }

    private void handleCallIce(UUID senderId, JsonNode root) {
        UUID targetId = UUID.fromString(root.path("targetUserId").asText());

        sendToUser(targetId, new CallIceCandidateDelivery(
                senderId,
                root.path("candidate").asText(),
                root.path("sdpMid").asText(),
                root.path("sdpMLineIndex").asInt()
        ));
    }

    private void handleTyping(UUID senderId, String senderName, String type, JsonNode root) {
        UUID conversationId = UUID.fromString(root.path("conversationId").asText());
        List<UUID> participantIds = conversationRepository.findParticipantIds(conversationId);

        com.fasterxml.jackson.databind.node.ObjectNode node = objectMapper.createObjectNode();
        node.put("type", type);
        node.put("conversationId", conversationId.toString());
        node.put("userId", senderId.toString());
        node.put("username", senderName);

        for (UUID pid : participantIds) {
            if (!pid.equals(senderId)) {
                sendToUserRaw(pid, node.toString());
            }
        }
    }

    private void handleMessageRead(UUID senderId, String senderName, JsonNode root) {
        UUID conversationId = UUID.fromString(root.path("conversationId").asText());
        UUID messageId = UUID.fromString(root.path("messageId").asText());

        chatService.markAsRead(messageId, senderId);

        List<UUID> participantIds = conversationRepository.findParticipantIds(conversationId);
        com.fasterxml.jackson.databind.node.ObjectNode node = objectMapper.createObjectNode();
        node.put("type", "message.read");
        node.put("conversationId", conversationId.toString());
        node.put("messageId", messageId.toString());
        node.put("userId", senderId.toString());

        for (UUID pid : participantIds) {
            if (!pid.equals(senderId)) {
                sendToUserRaw(pid, node.toString());
            }
        }
    }

    private void handleCallHangup(UUID senderId, JsonNode root) {
        UUID targetId = UUID.fromString(root.path("targetUserId").asText());
        sendToUser(targetId, new CallHangupDelivery(senderId));
    }

    private void handleCallReject(UUID senderId, JsonNode root) {
        UUID targetId = UUID.fromString(root.path("targetUserId").asText());
        sendToUser(targetId, new CallRejectDelivery(senderId));
    }

    // ── Helpers ──

    private void sendToConversationParticipants(UUID conversationId, WsMessage message) {
        List<UUID> participantIds = conversationRepository.findParticipantIds(conversationId);
        for (UUID participantId : participantIds) {
            sendToUser(participantId, message);
        }
    }

    private void broadcastPresence(UUID userId, String username, String status) {
        PresenceUpdate update = new PresenceUpdate(userId, username, status);
        for (UUID onlineUserId : presenceTracker.getOnlineUserIds()) {
            if (!onlineUserId.equals(userId)) {
                sendToUser(onlineUserId, update);
            }
        }
    }

    private void sendToUserRaw(UUID userId, String json) {
        WebSocketSession session = presenceTracker.getSession(userId);
        if (session != null && session.isOpen()) {
            try {
                session.sendMessage(new TextMessage(json));
            } catch (IOException e) {
                log.error("Failed to send message to user {}: {}", userId, e.getMessage());
            }
        }
    }

    private void sendToUser(UUID userId, WsMessage message) {
        WebSocketSession session = presenceTracker.getSession(userId);
        log.debug("sendToUser {} — session exists: {}, open: {}, type: {}",
                userId, session != null, session != null && session.isOpen(), message.type());
        if (session != null && session.isOpen()) {
            try {
                com.fasterxml.jackson.databind.node.ObjectNode node = objectMapper.valueToTree(message);
                node.put("type", message.type());
                session.sendMessage(new TextMessage(node.toString()));
            } catch (IOException e) {
                log.error("Failed to send message to user {}: {}", userId, e.getMessage());
            }
        }
    }

    private void sendError(WebSocketSession session, String errorMsg) {
        try {
            com.fasterxml.jackson.databind.node.ObjectNode node = objectMapper.createObjectNode();
            node.put("type", "error");
            node.put("message", errorMsg);
            session.sendMessage(new TextMessage(node.toString()));
        } catch (IOException e) {
            log.error("Failed to send error message: {}", e.getMessage());
        }
    }

    private UUID getUserId(WebSocketSession session) {
        return (UUID) session.getAttributes().get("userId");
    }

    private String getUsername(WebSocketSession session) {
        return (String) session.getAttributes().get("username");
    }
}