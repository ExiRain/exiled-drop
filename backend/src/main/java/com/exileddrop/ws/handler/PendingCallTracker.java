package com.exileddrop.ws.handler;

import lombok.AllArgsConstructor;
import lombok.Data;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Tracks active pending calls so that when a user reconnects,
 * we can re-deliver the call offer.
 */
@Component
public class PendingCallTracker {

    @Data
    @AllArgsConstructor
    public static class PendingCall {
        private UUID callerId;
        private String callerName;
        private String sdp;
        private String callType;
        private long createdAt;
    }

    // targetUserId → pending call from someone
    private final Map<UUID, PendingCall> pendingCalls = new ConcurrentHashMap<>();

    public void setPending(UUID targetUserId, UUID callerId, String callerName, String sdp, String callType) {
        pendingCalls.put(targetUserId, new PendingCall(callerId, callerName, sdp, callType, System.currentTimeMillis()));
    }

    /**
     * Returns and removes the pending call for this user, or null if none / expired.
     * Calls expire after 30 seconds.
     */
    public PendingCall consumePending(UUID targetUserId) {
        PendingCall call = pendingCalls.remove(targetUserId);
        if (call == null) return null;

        // Expire after 30 seconds
        if (System.currentTimeMillis() - call.getCreatedAt() > 30_000) {
            return null;
        }
        return call;
    }

    public void cancelPending(UUID targetUserId) {
        pendingCalls.remove(targetUserId);
    }

    public void cancelByCallerId(UUID callerId) {
        pendingCalls.entrySet().removeIf(e -> e.getValue().getCallerId().equals(callerId));
    }
}