package com.exileddrop.ws.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * All WebSocket message types exchanged between client and server.
 * Each has a "type" field for routing on both ends.
 */
public sealed interface WsMessage {

    String type();

    // ── Chat ──
    record ChatMessage(
        UUID conversationId,
        String content
    ) implements WsMessage {
        @Override public String type() { return "chat.message"; }
    }

    record ChatMessageDelivery(
        UUID id,
        UUID conversationId,
        UUID senderId,
        String senderName,
        String content,
        Instant createdAt
    ) implements WsMessage {
        @Override public String type() { return "chat.message.new"; }
    }

    // ── Presence ──
    record PresenceUpdate(
        UUID userId,
        String username,
        String status // ONLINE, OFFLINE
    ) implements WsMessage {
        @Override public String type() { return "presence.update"; }
    }

    // ── Call Signaling ──
    record CallOffer(
        UUID targetUserId,
        String sdp,
        String callType // AUDIO, VIDEO
    ) implements WsMessage {
        @Override public String type() { return "call.offer"; }
    }

    record CallOfferDelivery(
        UUID callerId,
        String callerName,
        String sdp,
        String callType
    ) implements WsMessage {
        @Override public String type() { return "call.offer"; }
    }

    record CallAnswer(
        UUID targetUserId,
        String sdp
    ) implements WsMessage {
        @Override public String type() { return "call.answer"; }
    }

    record CallAnswerDelivery(
        UUID answererId,
        String sdp
    ) implements WsMessage {
        @Override public String type() { return "call.answer"; }
    }

    record CallIceCandidate(
        UUID targetUserId,
        String candidate,
        String sdpMid,
        int sdpMLineIndex
    ) implements WsMessage {
        @Override public String type() { return "call.ice"; }
    }

    record CallIceCandidateDelivery(
        UUID fromUserId,
        String candidate,
        String sdpMid,
        int sdpMLineIndex
    ) implements WsMessage {
        @Override public String type() { return "call.ice"; }
    }

    record CallHangup(
        UUID targetUserId
    ) implements WsMessage {
        @Override public String type() { return "call.hangup"; }
    }

    record CallHangupDelivery(
        UUID fromUserId
    ) implements WsMessage {
        @Override public String type() { return "call.hangup"; }
    }

    record CallReject(
        UUID targetUserId
    ) implements WsMessage {
        @Override public String type() { return "call.reject"; }
    }

    record CallRejectDelivery(
        UUID fromUserId
    ) implements WsMessage {
        @Override public String type() { return "call.reject"; }
    }

    // ── Error ──
    record ErrorMessage(
        String message
    ) implements WsMessage {
        @Override public String type() { return "error"; }
    }
}
