package com.exileddrop.chat.entity;

import java.io.Serializable;
import java.util.UUID;
import lombok.*;

@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
@EqualsAndHashCode
public class MessageReadId implements Serializable {
    private UUID messageId;
    private UUID userId;
}