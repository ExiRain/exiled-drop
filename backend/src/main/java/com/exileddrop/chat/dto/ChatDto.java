package com.exileddrop.chat.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public sealed interface ChatDto {

    record CreateConversationRequest(
        @NotNull UUID participantId
    ) implements ChatDto {}

    record ConversationResponse(
        UUID id,
        List<ParticipantInfo> participants,
        MessageResponse lastMessage,
        Instant createdAt
    ) implements ChatDto {}

    record ParticipantInfo(
        UUID id,
        String username,
        String displayName,
        boolean online
    ) implements ChatDto {}

    record MessageResponse(
        UUID id,
        UUID conversationId,
        UUID senderId,
        String senderName,
        String content,
        Instant createdAt
    ) implements ChatDto {}

    record SendMessageRequest(
        @NotNull UUID conversationId,
        @NotBlank String content
    ) implements ChatDto {}
}
