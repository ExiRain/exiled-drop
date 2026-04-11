package com.exileddrop.ws.handler;

import com.exileddrop.auth.service.JwtService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.server.HandshakeInterceptor;
import org.springframework.web.util.UriComponentsBuilder;

import java.util.Map;
import java.util.UUID;

/**
 * Validates JWT token during WebSocket handshake.
 * Token is passed as a query parameter: ws://host/ws?token=xxx
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class JwtHandshakeInterceptor implements HandshakeInterceptor {

    private final JwtService jwtService;

    @Override
    public boolean beforeHandshake(
        ServerHttpRequest request,
        ServerHttpResponse response,
        WebSocketHandler wsHandler,
        Map<String, Object> attributes
    ) {
        String token = UriComponentsBuilder.fromUri(request.getURI())
            .build()
            .getQueryParams()
            .getFirst("token");

        if (token == null || !jwtService.isValidAccessToken(token)) {
            log.warn("WebSocket handshake rejected: invalid or missing token");
            return false;
        }

        UUID userId = jwtService.getUserId(token);
        String username = jwtService.getUsername(token);

        attributes.put("userId", userId);
        attributes.put("username", username);

        log.debug("WebSocket handshake accepted for user: {} ({})", username, userId);
        return true;
    }

    @Override
    public void afterHandshake(
        ServerHttpRequest request,
        ServerHttpResponse response,
        WebSocketHandler wsHandler,
        Exception exception
    ) {
        // no-op
    }
}
