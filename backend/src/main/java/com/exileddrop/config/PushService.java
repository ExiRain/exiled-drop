package com.exileddrop.config;

import com.exileddrop.auth.repository.DeviceTokenRepository;
import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class PushService {

    private final DeviceTokenRepository deviceTokenRepository;

    public void sendMessageNotification(UUID recipientId, String senderName, String content,
                                        UUID conversationId, UUID senderId) {
        if (FirebaseApp.getApps().isEmpty()) {
            log.warn("Firebase not initialized, skipping push");
            return;
        }

        var tokens = deviceTokenRepository.findByUserId(recipientId);
        log.info("Sending push to user {} — found {} device tokens", recipientId, tokens.size());

        tokens.forEach(device -> {
            try {
                Message message = Message.builder()
                        .setToken(device.getFcmToken())
                        .setNotification(Notification.builder()
                                .setTitle(senderName)
                                .setBody(content.length() > 100 ? content.substring(0, 100) + "..." : content)
                                .build())
                        .putData("type", "chat.message")
                        .putData("senderName", senderName)
                        .putData("senderId", senderId.toString())
                        .putData("conversationId", conversationId.toString())
                        .build();

                FirebaseMessaging.getInstance().send(message);
            } catch (Exception e) {
                log.error("Failed to send push to {}: {}", device.getFcmToken(), e.getMessage());
                if (e.getMessage() != null && e.getMessage().contains("not a valid FCM registration token")) {
                    deviceTokenRepository.delete(device);
                }
            }
        });
    }

    public void sendCallNotification(UUID recipientId, UUID callerId, String callerName, String callType) {
        if (FirebaseApp.getApps().isEmpty()) return;

        deviceTokenRepository.findByUserId(recipientId).forEach(device -> {
            try {
                Message message = Message.builder()
                        .setToken(device.getFcmToken())
                        .setNotification(Notification.builder()
                                .setTitle("Incoming " + (callType.equals("VIDEO") ? "Video" : "Voice") + " Call")
                                .setBody(callerName + " is calling...")
                                .build())
                        .putData("type", "call.offer")
                        .putData("callerId", callerId.toString())
                        .putData("callerName", callerName)
                        .putData("callType", callType)
                        .build();

                FirebaseMessaging.getInstance().send(message);
            } catch (Exception e) {
                log.error("Failed to send call push: {}", e.getMessage());
            }
        });
    }
}