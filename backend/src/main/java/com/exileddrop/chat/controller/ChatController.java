package com.exileddrop.chat.controller;

import com.exileddrop.chat.dto.ChatDto.*;
import com.exileddrop.chat.service.ChatService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/conversations")
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;

    @PostMapping
    public ResponseEntity<ConversationResponse> createConversation(
        @Valid @RequestBody CreateConversationRequest request,
        @AuthenticationPrincipal UUID userId
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(chatService.createOrGetConversation(userId, request));
    }

    @GetMapping
    public ResponseEntity<List<ConversationResponse>> listConversations(
        @AuthenticationPrincipal UUID userId
    ) {
        return ResponseEntity.ok(chatService.getConversations(userId));
    }

    @GetMapping("/{id}/messages")
    public ResponseEntity<Page<MessageResponse>> getMessages(
        @PathVariable UUID id,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "50") int size
    ) {
        return ResponseEntity.ok(chatService.getMessages(id, page, size));
    }
}
