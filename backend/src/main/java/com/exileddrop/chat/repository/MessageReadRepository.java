package com.exileddrop.chat.repository;

import com.exileddrop.chat.entity.MessageRead;
import com.exileddrop.chat.entity.MessageReadId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.*;

public interface MessageReadRepository extends JpaRepository<MessageRead, MessageReadId> {

    @Query("SELECT mr.messageId FROM MessageRead mr WHERE mr.userId = :userId AND mr.messageId IN :messageIds")
    Set<UUID> findReadMessageIds(@Param("userId") UUID userId, @Param("messageIds") Collection<UUID> messageIds);
}