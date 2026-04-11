package com.exileddrop.chat.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "message_reads")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
@Builder
@IdClass(MessageReadId.class)
public class MessageRead {

    @Id
    @Column(name = "message_id")
    private UUID messageId;

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "read_at", nullable = false)
    private Instant readAt;

    @PrePersist
    protected void onCreate() {
        if (readAt == null) readAt = Instant.now();
    }
}