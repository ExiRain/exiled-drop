package com.exileddrop.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public sealed interface AuthDto {

    record RegisterRequest(
        @NotBlank @Size(min = 3, max = 50) String username,
        @NotBlank @Size(min = 3, max = 100) String displayName,
        @NotBlank @Size(min = 6, max = 128) String password
    ) implements AuthDto {}

    record LoginRequest(
        @NotBlank String username,
        @NotBlank String password
    ) implements AuthDto {}

    record AuthResponse(
        String accessToken,
        String refreshToken,
        UserInfo user
    ) implements AuthDto {}

    record RefreshRequest(
        @NotBlank String refreshToken
    ) implements AuthDto {}

    record UserInfo(
        String id,
        String username,
        String displayName
    ) implements AuthDto {}
}
