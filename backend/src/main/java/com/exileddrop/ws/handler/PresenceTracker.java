package com.exileddrop.ws.handler;

import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketSession;

import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Tracks which users are online and maps userId <-> WebSocket sessions.
 * For MVP single-instance deployment; replace with Redis pub/sub for multi-instance.
 */
@Component
public class PresenceTracker {

    // userId -> session
    private final Map<UUID, WebSocketSession> userSessions = new ConcurrentHashMap<>();
    // sessionId -> userId (reverse lookup for disconnect)
    private final Map<String, UUID> sessionUsers = new ConcurrentHashMap<>();

    public void userConnected(UUID userId, WebSocketSession session) {
        // Close previous session if user reconnects
        WebSocketSession previous = userSessions.put(userId, session);
        if (previous != null && previous.isOpen()) {
            try { previous.close(); } catch (Exception ignored) {}
        }
        sessionUsers.put(session.getId(), userId);
    }

    public UUID userDisconnected(WebSocketSession session) {
        UUID userId = sessionUsers.remove(session.getId());
        if (userId != null) {
            userSessions.remove(userId, session);
        }
        return userId;
    }

    public boolean isOnline(UUID userId) {
        WebSocketSession session = userSessions.get(userId);
        return session != null && session.isOpen();
    }

    public WebSocketSession getSession(UUID userId) {
        return userSessions.get(userId);
    }

    public Set<UUID> getOnlineUserIds() {
        return userSessions.keySet();
    }
}
