package com.exileddrop.auth.repository;

import com.exileddrop.auth.entity.DeviceToken;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;

public interface DeviceTokenRepository extends JpaRepository<DeviceToken, UUID> {
    List<DeviceToken> findByUserId(UUID userId);
    Optional<DeviceToken> findByFcmToken(String fcmToken);
    void deleteByFcmToken(String fcmToken);
}