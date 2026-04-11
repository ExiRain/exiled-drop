package com.exileddrop.auth.controller;

import com.exileddrop.auth.entity.DeviceToken;
import com.exileddrop.auth.repository.DeviceTokenRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/devices")
@RequiredArgsConstructor
public class DeviceController {

    private final DeviceTokenRepository deviceTokenRepository;

    @PostMapping("/fcm-token")
    @Transactional
    public ResponseEntity<Void> registerToken(
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UUID userId
    ) {
        String token = body.get("token");
        if (token == null || token.isBlank()) {
            return ResponseEntity.badRequest().build();
        }

        // Upsert — if token exists, update the user; otherwise create
        deviceTokenRepository.findByFcmToken(token).ifPresentOrElse(
                existing -> existing.setUserId(userId),
                () -> deviceTokenRepository.save(DeviceToken.builder()
                        .userId(userId)
                        .fcmToken(token)
                        .build())
        );

        return ResponseEntity.ok().build();
    }
}