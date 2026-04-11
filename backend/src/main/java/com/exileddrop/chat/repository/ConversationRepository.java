package com.exileddrop.chat.repository;

import com.exileddrop.chat.entity.Conversation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.*;

public interface ConversationRepository extends JpaRepository<Conversation, UUID> {

    /**
     * Find all conversations where a given user is a participant.
     */
    @Query("""
        SELECT DISTINCT c FROM Conversation c
        JOIN c.participants p
        WHERE p.id = :userId
        """)
    List<Conversation> findByParticipantId(@Param("userId") UUID userId);

    /**
     * Find an existing 1:1 conversation between two users.
     * Returns empty if they haven't chatted yet.
     */
    @Query("""
        SELECT c FROM Conversation c
        JOIN c.participants p1
        JOIN c.participants p2
        WHERE p1.id = :userA AND p2.id = :userB
        """)
    Optional<Conversation> findDirectConversation(
        @Param("userA") UUID userA,
        @Param("userB") UUID userB
    );

    /**
     * Get participant user IDs for a conversation (avoids lazy loading issues).
     */
    @Query("""
        SELECT p.id FROM Conversation c
        JOIN c.participants p
        WHERE c.id = :conversationId
        """)
    List<UUID> findParticipantIds(@Param("conversationId") UUID conversationId);
}
