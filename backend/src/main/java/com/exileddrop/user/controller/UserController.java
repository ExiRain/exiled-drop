package com.exileddrop.user.controller;

import com.exileddrop.auth.dto.AuthDto.UserInfo;
import com.exileddrop.auth.entity.User;
import com.exileddrop.auth.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserRepository userRepository;

    @GetMapping("/me")
    public ResponseEntity<UserInfo> me(@AuthenticationPrincipal UUID userId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new IllegalArgumentException("User not found"));

        return ResponseEntity.ok(new UserInfo(
            user.getId().toString(),
            user.getUsername(),
            user.getDisplayName()
        ));
    }

    @GetMapping("/search")
    public ResponseEntity<List<UserInfo>> search(
        @RequestParam String q,
        @AuthenticationPrincipal UUID currentUserId
    ) {
        List<UserInfo> results = userRepository
            .findByUsernameContainingIgnoreCase(q.trim())
            .stream()
            .filter(u -> !u.getId().equals(currentUserId)) // exclude self
            .map(u -> new UserInfo(u.getId().toString(), u.getUsername(), u.getDisplayName()))
            .toList();

        return ResponseEntity.ok(results);
    }
}
