package com.exileddrop.ws.config;

import com.exileddrop.ws.handler.ExiledDropWebSocketHandler;
import com.exileddrop.ws.handler.JwtHandshakeInterceptor;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

@Configuration
@EnableWebSocket
@RequiredArgsConstructor
public class WebSocketConfig implements WebSocketConfigurer {

    private final ExiledDropWebSocketHandler webSocketHandler;
    private final JwtHandshakeInterceptor handshakeInterceptor;

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry
            .addHandler(webSocketHandler, "/ws")
            .addInterceptors(handshakeInterceptor)
            .setAllowedOrigins("*"); // MVP: allow all origins
    }
}
