package com.exileddrop.chat.service;

import com.exileddrop.auth.entity.User;
import com.exileddrop.auth.repository.UserRepository;
import com.exileddrop.chat.dto.ChatDto.*;
import com.exileddrop.chat.entity.Conversation;
import com.exileddrop.chat.entity.Message;
import com.exileddrop.chat.entity.MessageRead;
import com.exileddrop.chat.entity.MessageReadId;
import com.exileddrop.chat.repository.ConversationRepository;
import com.exileddrop.chat.repository.MessageReadRepository;
import com.exileddrop.chat.repository.MessageRepository;
import com.exileddrop.ws.handler.PresenceTracker;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

@Service
@RequiredArgsConstructor
public class ChatService {

    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final UserRepository userRepository;
    private final PresenceTracker presenceTracker;
    private final MessageReadRepository messageReadRepository;

    @Transactional
    public ConversationResponse createOrGetConversation(UUID currentUserId, CreateConversationRequest request) {
        // Check if conversation already exists
        Optional<Conversation> existing = conversationRepository
            .findDirectConversation(currentUserId, request.participantId());

        if (existing.isPresent()) {
            return toConversationResponse(existing.get(), currentUserId);
        }

        // Create new conversation
        User currentUser = userRepository.findById(currentUserId)
            .orElseThrow(() -> new IllegalArgumentException("User not found"));
        User otherUser = userRepository.findById(request.participantId())
            .orElseThrow(() -> new IllegalArgumentException("Participant not found"));

        Conversation conversation = Conversation.builder().build();
        conversation.getParticipants().add(currentUser);
        conversation.getParticipants().add(otherUser);
        conversation = conversationRepository.save(conversation);

        return toConversationResponse(conversation, currentUserId);
    }

    @Transactional
    public void markAsRead(UUID messageId, UUID userId) {
        MessageReadId id = new MessageReadId(messageId, userId);
        if (!messageReadRepository.existsById(id)) {
            messageReadRepository.save(MessageRead.builder()
                    .messageId(messageId)
                    .userId(userId)
                    .build());
        }
    }

    @Transactional(readOnly = true)
    public List<ConversationResponse> getConversations(UUID userId) {
        return conversationRepository.findByParticipantId(userId)
            .stream()
            .map(c -> toConversationResponse(c, userId))
            .toList();
    }

    @Transactional(readOnly = true)
    public Page<MessageResponse> getMessages(UUID conversationId, int page, int size) {
        return messageRepository
            .findByConversationIdOrderByCreatedAtDesc(conversationId, PageRequest.of(page, size))
            .map(this::toMessageResponse);
    }

    @Transactional
    public Message saveMessage(UUID conversationId, UUID senderId, String content) {
        Conversation conversation = conversationRepository.findById(conversationId)
            .orElseThrow(() -> new IllegalArgumentException("Conversation not found"));
        User sender = userRepository.findById(senderId)
            .orElseThrow(() -> new IllegalArgumentException("User not found"));

        Message message = Message.builder()
            .conversation(conversation)
            .sender(sender)
            .content(content)
            .build();

        return messageRepository.save(message);
    }

    private ConversationResponse toConversationResponse(Conversation conv, UUID currentUserId) {
        List<ParticipantInfo> participants = conv.getParticipants().stream()
            .map(u -> new ParticipantInfo(
                u.getId(),
                u.getUsername(),
                u.getDisplayName(),
                presenceTracker.isOnline(u.getId())
            ))
            .toList();

        MessageResponse lastMessage = messageRepository
            .findLatestByConversationId(conv.getId())
            .map(this::toMessageResponse)
            .orElse(null);

        return new ConversationResponse(conv.getId(), participants, lastMessage, conv.getCreatedAt());
    }

    private MessageResponse toMessageResponse(Message msg) {
        return new MessageResponse(
            msg.getId(),
            msg.getConversation().getId(),
            msg.getSender().getId(),
            msg.getSender().getDisplayName(),
            msg.getContent(),
            msg.getCreatedAt()
        );
    }
}
