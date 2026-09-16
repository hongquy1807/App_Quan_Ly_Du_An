-- MySQL dump 10.13  Distrib 8.0.46, for Win64 (x86_64)
--
-- Host: localhost    Database: quanlyduan
-- ------------------------------------------------------
-- Server version	8.0.46

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `conversation_members`
--

DROP TABLE IF EXISTS `conversation_members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `conversation_members` (
  `id` int NOT NULL AUTO_INCREMENT,
  `conversation_id` int NOT NULL,
  `user_id` int NOT NULL,
  `joined_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_read_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_conversation_member` (`conversation_id`,`user_id`),
  KEY `idx_conversation_members_user_id` (`user_id`),
  CONSTRAINT `conversation_members_conversation_fk` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `conversation_members_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `conversation_members`
--

LOCK TABLES `conversation_members` WRITE;
/*!40000 ALTER TABLE `conversation_members` DISABLE KEYS */;
INSERT INTO `conversation_members` VALUES (1,1,6,'2026-08-16 04:45:32',NULL),(2,1,8,'2026-08-16 04:45:32',NULL),(3,2,8,'2026-09-14 10:12:41',NULL),(4,2,11,'2026-09-14 10:12:41',NULL);
/*!40000 ALTER TABLE `conversation_members` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `conversations`
--

DROP TABLE IF EXISTS `conversations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `conversations` (
  `id` int NOT NULL AUTO_INCREMENT,
  `type` enum('project','direct') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'direct',
  `project_id` int DEFAULT NULL,
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_conversations_type` (`type`),
  KEY `idx_conversations_project_id` (`project_id`),
  CONSTRAINT `conversations_project_fk` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `conversations`
--

LOCK TABLES `conversations` WRITE;
/*!40000 ALTER TABLE `conversations` DISABLE KEYS */;
INSERT INTO `conversations` VALUES (1,'direct',NULL,NULL,'2026-08-16 04:45:32','2026-09-14 10:12:56'),(2,'direct',NULL,NULL,'2026-09-14 10:12:41','2026-09-16 16:07:15');
/*!40000 ALTER TABLE `conversations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `direct_conversations`
--

DROP TABLE IF EXISTS `direct_conversations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `direct_conversations` (
  `id` int NOT NULL AUTO_INCREMENT,
  `conversation_id` int NOT NULL,
  `user_one_id` int NOT NULL,
  `user_two_id` int NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_direct_pair` (`user_one_id`,`user_two_id`),
  UNIQUE KEY `uq_direct_conversation` (`conversation_id`),
  KEY `direct_conversations_user_two_fk` (`user_two_id`),
  CONSTRAINT `direct_conversations_conversation_fk` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `direct_conversations_user_one_fk` FOREIGN KEY (`user_one_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `direct_conversations_user_two_fk` FOREIGN KEY (`user_two_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `direct_conversations`
--

LOCK TABLES `direct_conversations` WRITE;
/*!40000 ALTER TABLE `direct_conversations` DISABLE KEYS */;
INSERT INTO `direct_conversations` VALUES (1,1,6,8,'2026-08-16 04:45:32'),(2,2,8,11,'2026-09-14 10:12:41');
/*!40000 ALTER TABLE `direct_conversations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `electronic_cvs`
--

DROP TABLE IF EXISTS `electronic_cvs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `electronic_cvs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `objective` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `education` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `skills` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `soft_skills` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `languages` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `projects` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `certificates` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_electronic_cvs_user_id` (`user_id`),
  CONSTRAINT `electronic_cvs_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `electronic_cvs`
--

LOCK TABLES `electronic_cvs` WRITE;
/*!40000 ALTER TABLE `electronic_cvs` DISABLE KEYS */;
INSERT INTO `electronic_cvs` VALUES (1,8,'Công nghệ thông tin','phát triển nghề nghiệp, mong muốn tìm việc','Đại học Công nghệ thông tin\n2022 - 2026','phần mềm \nphần cứng \n3d','thuyết trình\nlàm việc nhóm\nquản lý thời gian','tiếng anh\ntiếng trung','ád\nqwerzop','Aws\nlập trình web','2026-08-16 05:17:31','2026-08-16 06:26:10'),(19,11,'Công nghệ thông tin','Trở thành lập trình viên phát triển ứng dụng di động','Đại học Bình Dương','node.js\nflutter\nreact native\nMySQL','làm việc nhóm','Tiếng Anh \nTiếng Trung','Web bán hàng','AWS - cloud','2026-09-14 03:27:57','2026-09-16 16:08:19');
/*!40000 ALTER TABLE `electronic_cvs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `feedback_attachments`
--

DROP TABLE IF EXISTS `feedback_attachments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `feedback_attachments` (
  `id` int NOT NULL AUTO_INCREMENT,
  `feedback_id` int NOT NULL,
  `file_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `file_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `file_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `mime_type` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `file_size` bigint DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_feedback_attachments_feedback_id` (`feedback_id`),
  CONSTRAINT `feedback_attachments_feedback_fk` FOREIGN KEY (`feedback_id`) REFERENCES `feedbacks` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `feedback_attachments`
--

LOCK TABLES `feedback_attachments` WRITE;
/*!40000 ALTER TABLE `feedback_attachments` DISABLE KEYS */;
/*!40000 ALTER TABLE `feedback_attachments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `feedbacks`
--

DROP TABLE IF EXISTS `feedbacks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `feedbacks` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int DEFAULT NULL,
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_feedbacks_user_id` (`user_id`),
  KEY `idx_feedbacks_status` (`status`),
  CONSTRAINT `feedbacks_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `feedbacks`
--

LOCK TABLES `feedbacks` WRITE;
/*!40000 ALTER TABLE `feedbacks` DISABLE KEYS */;
INSERT INTO `feedbacks` VALUES (1,8,'fix bug','i cant create new project','pending','2026-08-05 05:51:12','2026-08-05 05:51:12');
/*!40000 ALTER TABLE `feedbacks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `friendships`
--

DROP TABLE IF EXISTS `friendships`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `friendships` (
  `id` int NOT NULL AUTO_INCREMENT,
  `requester_id` int NOT NULL,
  `addressee_id` int NOT NULL,
  `status` enum('pending','accepted','rejected','cancelled','blocked') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `requested_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `responded_at` datetime DEFAULT NULL,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_friend_request_direction` (`requester_id`,`addressee_id`),
  KEY `idx_friendships_requester_id` (`requester_id`),
  KEY `idx_friendships_addressee_id` (`addressee_id`),
  KEY `idx_friendships_status` (`status`),
  CONSTRAINT `friendships_addressee_fk` FOREIGN KEY (`addressee_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `friendships_requester_fk` FOREIGN KEY (`requester_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `friendships_not_self` CHECK ((`requester_id` <> `addressee_id`))
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `friendships`
--

LOCK TABLES `friendships` WRITE;
/*!40000 ALTER TABLE `friendships` DISABLE KEYS */;
INSERT INTO `friendships` VALUES (1,6,8,'accepted','2026-08-16 03:39:24','2026-08-16 04:07:42','2026-08-16 04:07:42'),(2,11,8,'accepted','2026-09-14 03:19:35','2026-09-14 03:20:11','2026-09-14 03:20:11'),(3,6,11,'pending','2026-09-14 03:20:44',NULL,'2026-09-14 03:20:44');
/*!40000 ALTER TABLE `friendships` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `messages`
--

DROP TABLE IF EXISTS `messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `messages` (
  `id` int NOT NULL AUTO_INCREMENT,
  `conversation_id` int DEFAULT NULL,
  `sender_id` int NOT NULL,
  `receiver_id` int NOT NULL,
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `file_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `file_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `read` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `sender_id` (`sender_id`),
  KEY `receiver_id` (`receiver_id`),
  KEY `idx_messages_conversation_id` (`conversation_id`),
  CONSTRAINT `messages_conversation_fk` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `messages_ibfk_1` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `messages_ibfk_2` FOREIGN KEY (`receiver_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `messages`
--

LOCK TABLES `messages` WRITE;
/*!40000 ALTER TABLE `messages` DISABLE KEYS */;
INSERT INTO `messages` VALUES (6,NULL,6,2,'Chào anh An, em đã nhận task kiểm thử dự án bán hàng nhé!',NULL,NULL,'2026-07-10 01:09:47','2026-08-16 04:10:47',0),(7,NULL,2,6,'Ok Quý, em ưu tiên test module giỏ hàng trước nha.',NULL,NULL,'2026-07-10 01:09:47','2026-08-16 04:10:47',0),(8,1,8,6,'xin chàoo',NULL,NULL,'2026-08-16 04:46:34','2026-09-13 22:22:17',1),(9,1,8,6,'helu',NULL,NULL,'2026-09-14 10:12:56','2026-09-14 10:12:56',0),(10,2,8,11,'holeeee',NULL,NULL,'2026-09-14 10:13:06','2026-09-14 10:13:09',1),(11,2,8,11,'helooo',NULL,NULL,'2026-09-14 10:13:10','2026-09-14 10:13:14',1),(12,2,11,8,'xin chào',NULL,NULL,'2026-09-16 16:07:15','2026-09-16 16:07:15',0);
/*!40000 ALTER TABLE `messages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notifications` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'general',
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `data` json DEFAULT NULL,
  `read` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=109 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notifications`
--

LOCK TABLES `notifications` WRITE;
/*!40000 ALTER TABLE `notifications` DISABLE KEYS */;
INSERT INTO `notifications` VALUES (8,8,'project_invitation','Bạn được mời tham gia dự án hhhh.','{\"project_id\": 7, \"invitation_id\": 1}',1,'2026-07-27 17:27:05'),(9,6,'task','Bạn được giao nhiệm vụ mới: lllllhh','{\"task_id\": 11, \"project_id\": 7}',1,'2026-07-27 17:34:34'),(10,8,'task','Bạn được giao nhiệm vụ mới: test','{\"task_id\": 12, \"project_id\": 7}',1,'2026-07-29 04:36:29'),(11,8,'task','Nhiệm vụ test đã được đánh dấu hoàn thành.','{\"task_id\": 12, \"project_id\": 7}',1,'2026-07-29 04:37:03'),(12,6,'task','Bạn được giao nhiệm vụ mới: bnj','{\"task_id\": 13, \"project_id\": 7}',1,'2026-07-29 04:37:44'),(13,9,'project_invitation','Bạn được mời tham gia dự án hhhh.','{\"project_id\": 7, \"invitation_id\": 2}',0,'2026-07-29 04:39:21'),(14,8,'project_invitation','Bạn được mời tham gia dự án qqqqq.','{\"project_id\": 9, \"invitation_id\": 3}',1,'2026-07-29 04:41:44'),(15,9,'project_invitation','Bạn được mời tham gia dự án qqqqq.','{\"project_id\": 9, \"invitation_id\": 4}',0,'2026-07-29 04:41:44'),(16,9,'task','Bạn được giao nhiệm vụ mới: ggg','{\"task_id\": 14, \"project_id\": 9}',0,'2026-07-29 04:43:23'),(17,8,'project_invitation','Bạn được mời tham gia dự án tt55zz.','{\"project_id\": 10, \"invitation_id\": 5}',1,'2026-07-29 04:50:23'),(18,9,'project_invitation','Bạn được mời tham gia dự án qwerzop.','{\"project_id\": 11, \"invitation_id\": 6}',0,'2026-07-29 04:54:17'),(19,6,'project_invitation','Bạn được mời tham gia dự án tk q.','{\"project_id\": 12, \"invitation_id\": 7}',1,'2026-07-29 04:58:00'),(20,9,'project_invitation','Bạn được mời tham gia dự án tk q.','{\"project_id\": 12, \"invitation_id\": 8}',0,'2026-07-29 04:58:25'),(21,8,'project_invitation','Bạn được mời tham gia dự án tk q.','{\"project_id\": 12, \"invitation_id\": 9}',1,'2026-07-29 05:04:22'),(22,8,'task','Bạn được giao nhiệm vụ mới: ruu','{\"task_id\": 15, \"project_id\": 7}',1,'2026-07-29 06:07:09'),(23,6,'task','Nhiệm vụ bnj đã được đánh dấu hoàn thành.','{\"task_id\": 13, \"project_id\": 7}',1,'2026-07-29 06:42:57'),(24,6,'task','Nhiệm vụ bnj đã được đánh dấu hoàn thành.','{\"task_id\": 13, \"project_id\": 7}',1,'2026-07-29 07:02:18'),(25,6,'task','Nhiệm vụ bnj đã được đánh dấu hoàn thành.','{\"task_id\": 13, \"project_id\": 7}',1,'2026-07-29 07:02:49'),(26,6,'task','Nhiệm vụ bnj đã được đánh dấu hoàn thành.','{\"task_id\": 13, \"project_id\": 7}',1,'2026-07-29 07:21:27'),(27,8,'task','Bạn được giao nhiệm vụ mới: ts2','{\"task_id\": 17, \"project_id\": 11}',1,'2026-07-29 07:28:39'),(28,6,'task','Bạn được giao nhiệm vụ mới: f hk klobtxr','{\"task_id\": 20, \"project_id\": 9}',1,'2026-07-29 07:43:22'),(29,6,'task','Bạn được giao nhiệm vụ mới: 5xr6ctih h i hivy7vhhvhu bhi','{\"task_id\": 21, \"project_id\": 9}',1,'2026-07-29 07:44:01'),(30,6,'project_invitation','Bạn được mời tham gia dự án ád.','{\"project_id\": 8, \"invitation_id\": 11}',1,'2026-07-29 07:48:23'),(31,8,'project_invitation','Bạn được mời tham gia dự án s3zcf5cc5ug.','{\"project_id\": 13, \"invitation_id\": 12}',1,'2026-07-29 07:51:00'),(32,9,'project_invitation','Bạn được mời tham gia dự án s3zcf5cc5ug.','{\"project_id\": 13, \"invitation_id\": 13}',0,'2026-07-29 07:51:00'),(33,10,'project_invitation','Bạn được mời tham gia dự án s3zcf5cc5ug.','{\"project_id\": 13, \"invitation_id\": 14}',0,'2026-07-29 07:51:00'),(34,8,'project_invitation','Bạn được mời tham gia dự án s3zcf5cc5ug.','{\"project_id\": 13, \"invitation_id\": 15}',1,'2026-07-29 07:57:40'),(35,6,'project_invitation','Bạn được mời tham gia dự án ád.','{\"project_id\": 8, \"invitation_id\": 16}',1,'2026-07-29 08:13:46'),(36,6,'task','Báº¡n Ä‘Æ°á»£c giao nhiá»‡m vá»¥ má»›i: yyui','{\"task_id\": 22, \"project_id\": 13}',1,'2026-07-29 08:14:34'),(37,8,'project_invitation','Bạn được mời tham gia dự án qqqqq.','{\"project_id\": 9, \"invitation_id\": 17}',1,'2026-07-29 08:15:40'),(38,8,'project_invitation','Bạn được mời tham gia dự án s3zcf5cc5ug.','{\"project_id\": 13, \"invitation_id\": 18}',1,'2026-07-29 08:16:29'),(39,8,'project_invitation','Bạn được mời tham gia dự án s3zcf5cc5ug.','{\"project_id\": 13, \"invitation_id\": 19}',1,'2026-07-29 08:21:33'),(40,8,'project_invitation','Bạn được mời tham gia dự án s3zcf5cc5ug.','{\"project_id\": 13, \"invitation_id\": 21}',1,'2026-07-29 08:29:31'),(41,8,'project_invitation','Bạn được mời tham gia dự án s3zcf5cc5ug.','{\"project_id\": 13, \"invitation_id\": 22}',1,'2026-07-29 08:35:57'),(42,6,'project_invitation','Bạn được mời tham gia dự án ád.','{\"project_id\": 8, \"invitation_id\": 23}',1,'2026-07-29 08:37:37'),(43,9,'project_invitation','Bạn được mời tham gia dự án ád.','{\"project_id\": 8, \"invitation_id\": 24}',0,'2026-07-29 08:38:00'),(44,6,'project_invitation','Bạn được mời tham gia dự án ád.','{\"project_id\": 8, \"invitation_id\": 25}',1,'2026-07-29 08:39:20'),(45,10,'project_invitation','Bạn được mời tham gia dự án ád.','{\"project_id\": 8, \"invitation_id\": 26}',0,'2026-07-29 08:39:35'),(46,9,'task','Báº¡n Ä‘Æ°á»£c giao nhiá»‡m vá»¥ má»›i: task1','{\"task_id\": 23, \"project_id\": 7}',0,'2026-07-29 08:52:17'),(47,6,'task','Báº¡n Ä‘Æ°á»£c giao nhiá»‡m vá»¥ má»›i: thiet ke web','{\"task_id\": 24, \"project_id\": 7}',1,'2026-07-29 09:51:39'),(48,8,'task','Báº¡n Ä‘Æ°á»£c giao nhiá»‡m vá»¥ má»›i: thiet ke web','{\"task_id\": 25, \"project_id\": 7}',1,'2026-07-29 09:51:39'),(49,9,'task','Báº¡n Ä‘Æ°á»£c giao nhiá»‡m vá»¥ má»›i: thiet ke web','{\"task_id\": 26, \"project_id\": 7}',0,'2026-07-29 09:51:39'),(50,6,'task','Báº¡n Ä‘Æ°á»£c giao nhiá»‡m vá»¥ má»›i: tìm one piece','{\"task_id\": 27, \"project_id\": 14}',1,'2026-07-31 04:40:52'),(51,6,'task','Báº¡n Ä‘Æ°á»£c giao nhiá»‡m vá»¥ má»›i: tìm nhạc hay','{\"task_id\": 28, \"project_id\": 14}',1,'2026-07-31 04:58:33'),(52,9,'task','Nhiệm vụ ggg đã được đánh dấu hoàn thành.','{\"task_id\": 14, \"project_id\": 9}',0,'2026-07-31 05:03:20'),(53,8,'project_invitation','Bạn được mời tham gia dự án chẳng nhớ đã qua bao mùa giao thừa, mà mình mãi mất nhau.','{\"project_id\": 14, \"invitation_id\": 27}',1,'2026-07-31 05:37:04'),(54,9,'project_invitation','Bạn được mời tham gia dự án chẳng nhớ đã qua bao mùa giao thừa, mà mình mãi mất nhau.','{\"project_id\": 14, \"invitation_id\": 28}',0,'2026-07-31 05:38:00'),(55,10,'project_invitation','Bạn được mời tham gia dự án chẳng nhớ đã qua bao mùa giao thừa, mà mình mãi mất nhau.','{\"project_id\": 14, \"invitation_id\": 29}',0,'2026-07-31 05:38:23'),(56,10,'project_invitation','Bạn được mời tham gia dự án chẳng nhớ đã qua bao mùa giao thừa, mà mình mãi mất nhau.','{\"project_id\": 14, \"invitation_id\": 30}',0,'2026-07-31 05:44:06'),(57,8,'project_invitation','Bạn được mời tham gia dự án chẳng nhớ đã qua bao mùa giao thừa, mà mình mãi mất nhau.','{\"project_id\": 14, \"invitation_id\": 31}',1,'2026-07-31 06:12:52'),(58,9,'project_invitation','Bạn được mời tham gia dự án chẳng nhớ đã qua bao mùa giao thừa, mà mình mãi mất nhau.','{\"project_id\": 14, \"invitation_id\": 32}',0,'2026-07-31 06:13:09'),(59,6,'task','Báº¡n Ä‘Æ°á»£c giao nhiá»‡m vá»¥ má»›i: Xây dựng giao diện đăng nhập','{\"task_id\": 29, \"project_id\": 16}',1,'2026-07-31 08:44:03'),(60,8,'project_invitation','Bạn được mời tham gia dự án Lập trình di động.','{\"project_id\": 16, \"invitation_id\": 33}',1,'2026-07-31 08:48:16'),(61,10,'project_invitation','Bạn được mời tham gia dự án Lập trình di động.','{\"project_id\": 16, \"invitation_id\": 34}',0,'2026-07-31 08:48:22'),(62,6,'task','Báº¡n Ä‘Æ°á»£c giao nhiá»‡m vá»¥ má»›i: h088','{\"task_id\": 32, \"project_id\": 16}',1,'2026-08-03 18:25:53'),(63,6,'task','Báº¡n Ä‘Æ°á»£c giao nhiá»‡m vá»¥ má»›i: mua bánh kẹo','{\"task_id\": 34, \"project_id\": 17}',1,'2026-08-03 18:29:25'),(64,6,'task','Báº¡n Ä‘Æ°á»£c giao nhiá»‡m vá»¥ má»›i: mua váy tặng sn','{\"task_id\": 35, \"project_id\": 17}',1,'2026-08-03 18:30:33'),(65,8,'project_message','Bạn có tin nhắn mới ở dự án ád.','{\"message_id\": 2, \"project_id\": 8}',1,'2026-08-05 05:08:46'),(66,9,'project_message','Bạn có tin nhắn mới ở dự án ád.','{\"message_id\": 2, \"project_id\": 8}',0,'2026-08-05 05:08:46'),(67,10,'project_message','Bạn có tin nhắn mới ở dự án ád.','{\"message_id\": 2, \"project_id\": 8}',0,'2026-08-05 05:08:46'),(68,6,'project_message','Bạn có tin nhắn mới ở dự án ád.','{\"message_id\": 3, \"project_id\": 8}',1,'2026-08-05 05:09:13'),(69,9,'project_message','Bạn có tin nhắn mới ở dự án ád.','{\"message_id\": 3, \"project_id\": 8}',0,'2026-08-05 05:09:13'),(70,10,'project_message','Bạn có tin nhắn mới ở dự án ád.','{\"message_id\": 3, \"project_id\": 8}',0,'2026-08-05 05:09:13'),(71,6,'task','Nhiệm vụ h088 đã được đánh dấu hoàn thành.','{\"task_id\": 32, \"project_id\": 16}',1,'2026-08-11 04:34:28'),(72,6,'task','Nhiệm vụ h088 đã được đánh dấu hoàn thành.','{\"task_id\": 32, \"project_id\": 16}',1,'2026-08-11 04:34:49'),(73,6,'task','Nhiệm vụ h088 đã được đánh dấu hoàn thành.','{\"task_id\": 32, \"project_id\": 16}',1,'2026-08-11 04:34:53'),(74,6,'task','Nhiệm vụ h088 đã được đánh dấu hoàn thành.','{\"task_id\": 32, \"project_id\": 16}',1,'2026-08-11 04:38:51'),(75,6,'task','Nhiệm vụ h088 đã được đánh dấu hoàn thành.','{\"task_id\": 32, \"project_id\": 16}',1,'2026-08-11 04:42:01'),(76,6,'task','Nhiệm vụ h088 đã được đánh dấu hoàn thành.','{\"task_id\": 32, \"project_id\": 16}',1,'2026-08-11 04:42:04'),(77,6,'task','Báº¡n Ä‘Æ°á»£c giao nhiá»‡m vá»¥ má»›i: jtxhzfkgzgxk','{\"task_id\": 37, \"project_id\": 16}',1,'2026-08-12 03:19:47'),(78,10,'task','Báº¡n Ä‘Æ°á»£c giao nhiá»‡m vá»¥ má»›i: xũigoyf','{\"task_id\": 38, \"project_id\": 16}',0,'2026-08-12 05:30:49'),(79,6,'task','Báº¡n Ä‘Æ°á»£c giao nhiá»‡m vá»¥ má»›i: ctx vg66b','{\"task_id\": 39, \"project_id\": 16}',1,'2026-08-12 06:03:03'),(80,6,'deadline','ctx vg66b còn 3 ngày đến hạn.','{\"task_id\": 39, \"days_left\": 3, \"project_id\": 16, \"project_name\": \"Lập trình di động\", \"reminder_date\": \"2026-08-12\"}',1,'2026-08-12 19:24:28'),(81,8,'friend_request','Bạn có một lời mời kết bạn mới.','{\"requester_id\": 6}',1,'2026-08-16 03:39:24'),(82,6,'direct_message','Bạn có một tin nhắn mới.','{\"friend_id\": 8, \"message_id\": 8}',1,'2026-08-16 04:46:34'),(83,8,'task','Báº¡n Ä‘Æ°á»£c giao nhiá»‡m vá»¥ má»›i: f yv y','{\"task_id\": 40, \"project_id\": 16}',1,'2026-08-16 06:32:12'),(84,6,'project_invitation','Bạn được mời tham gia dự án td ftvv.','{\"project_id\": 18, \"invitation_id\": 36}',1,'2026-08-16 06:48:57'),(85,8,'task','Báº¡n Ä‘Æ°á»£c giao nhiá»‡m vá»¥ má»›i: hhhhj','{\"task_id\": 41, \"project_id\": 16}',0,'2026-08-16 07:16:43'),(86,8,'project_invitation','Bạn được mời tham gia dự án test.','{\"project_id\": 19, \"invitation_id\": 37}',0,'2026-09-13 22:04:48'),(87,6,'task','Bạn được giao nhiệm vụ mới: test1','{\"task_id\": 42, \"project_id\": 19}',1,'2026-09-13 22:10:21'),(88,6,'task','Bạn được giao nhiệm vụ mới: test 2','{\"task_id\": 43, \"project_id\": 19}',1,'2026-09-13 22:11:24'),(89,6,'task','Bạn được giao nhiệm vụ mới: test 3','{\"task_id\": 44, \"project_id\": 19}',0,'2026-09-14 00:32:21'),(90,6,'task','Bạn được giao nhiệm vụ mới: test 4','{\"task_id\": 45, \"project_id\": 19}',0,'2026-09-14 00:34:54'),(91,11,'task','Bạn được giao nhiệm vụ mới: Kiểm thử chức năng','{\"task_id\": 46, \"project_id\": 20}',1,'2026-09-14 03:05:06'),(92,11,'task','Bạn được giao nhiệm vụ mới: FE Xây dựng giao diện','{\"task_id\": 47, \"project_id\": 20}',1,'2026-09-14 03:06:19'),(93,11,'deadline','FE Xây dựng giao diện còn 2 ngày đến hạn.','{\"task_id\": 47, \"days_left\": 2, \"project_id\": 20, \"project_name\": \"Lập trình mobile\", \"reminder_date\": \"2026-09-13\"}',1,'2026-09-14 03:06:32'),(94,6,'project_invitation','Bạn được mời tham gia dự án Lập trình mobile.','{\"project_id\": 20, \"invitation_id\": 38}',0,'2026-09-14 03:08:49'),(95,6,'task','Bạn được giao nhiệm vụ mới: BE xây dựng API','{\"task_id\": 48, \"project_id\": 20}',0,'2026-09-14 03:10:26'),(96,11,'deadline','DB thiết kế database còn 3 ngày đến hạn.','{\"task_id\": 49, \"days_left\": 3, \"project_id\": 20, \"project_name\": \"Lập trình mobile\", \"reminder_date\": \"2026-09-13\"}',1,'2026-09-14 03:11:43'),(97,8,'friend_request','Bạn có một lời mời kết bạn mới.','{\"requester_id\": 11}',0,'2026-09-14 03:19:35'),(98,6,'friend_request','Bạn có một lời mời kết bạn mới.','{\"requester_id\": 11}',0,'2026-09-14 03:19:46'),(99,11,'friend_request','Bạn có một lời mời kết bạn mới.','{\"requester_id\": 6}',1,'2026-09-14 03:20:44'),(100,11,'deadline','FE Xây dựng giao diện còn 2 ngày đến hạn.','{\"task_id\": 47, \"days_left\": 2, \"project_id\": 20, \"project_name\": \"Lập trình mobile\", \"reminder_date\": \"2026-09-14\"}',1,'2026-09-14 10:10:26'),(101,6,'direct_message','Bạn có một tin nhắn mới.','{\"friend_id\": 8, \"message_id\": 9}',0,'2026-09-14 10:12:56'),(102,11,'direct_message','Bạn có một tin nhắn mới.','{\"friend_id\": 8, \"message_id\": 10}',1,'2026-09-14 10:13:06'),(103,11,'direct_message','Bạn có một tin nhắn mới.','{\"friend_id\": 8, \"message_id\": 11}',1,'2026-09-14 10:13:10'),(104,11,'deadline','DB thiết kế database còn 2 ngày đến hạn.','{\"task_id\": 49, \"days_left\": 2, \"project_id\": 20, \"project_name\": \"Lập trình mobile\", \"reminder_date\": \"2026-09-16\"}',1,'2026-09-16 15:52:08'),(105,8,'project_invitation','Bạn được mời tham gia dự án Lập trình mobile.','{\"project_id\": 20, \"invitation_id\": 39}',0,'2026-09-16 16:03:35'),(106,11,'task','Bạn được giao nhiệm vụ mới: test app','{\"task_id\": 53, \"project_id\": 20}',1,'2026-09-16 16:04:31'),(107,8,'direct_message','Bạn có một tin nhắn mới.','{\"friend_id\": 11, \"message_id\": 12}',0,'2026-09-16 16:07:15'),(108,8,'project_invitation','Bạn được mời tham gia dự án Lập trình web.','{\"project_id\": 21, \"invitation_id\": 40}',0,'2026-09-16 16:09:54');
/*!40000 ALTER TABLE `notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `password_resets`
--

DROP TABLE IF EXISTS `password_resets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `password_resets` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `token` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `expires_at` bigint NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `token` (`token`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `password_resets_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `password_resets`
--

LOCK TABLES `password_resets` WRITE;
/*!40000 ALTER TABLE `password_resets` DISABLE KEYS */;
INSERT INTO `password_resets` VALUES (7,11,'28912b0ef4e4bbc54196ee0058faecba4b3162f028fc94fc99b73c805bf81a52',1789550785846,'2026-09-16 16:11:25');
/*!40000 ALTER TABLE `password_resets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `project_invitations`
--

DROP TABLE IF EXISTS `project_invitations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `project_invitations` (
  `id` int NOT NULL AUTO_INCREMENT,
  `project_id` int NOT NULL,
  `inviter_id` int NOT NULL,
  `invitee_email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `invitee_id` int DEFAULT NULL,
  `project_role_id` int DEFAULT '3',
  `status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `responded_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `project_id` (`project_id`),
  KEY `inviter_id` (`inviter_id`),
  KEY `invitee_id` (`invitee_id`),
  KEY `project_role_id` (`project_role_id`),
  CONSTRAINT `project_invitations_invitee_fk` FOREIGN KEY (`invitee_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `project_invitations_inviter_fk` FOREIGN KEY (`inviter_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `project_invitations_project_fk` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`) ON DELETE CASCADE,
  CONSTRAINT `project_invitations_role_fk` FOREIGN KEY (`project_role_id`) REFERENCES `project_roles` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=41 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `project_invitations`
--

LOCK TABLES `project_invitations` WRITE;
/*!40000 ALTER TABLE `project_invitations` DISABLE KEYS */;
INSERT INTO `project_invitations` VALUES (5,10,9,'test@gmail.com',8,3,'declined','2026-07-29 04:50:23','2026-07-29 08:28:02'),(7,12,10,'hongquy@gmail.com',6,3,'accepted','2026-07-29 04:58:00','2026-07-29 09:53:34'),(8,12,10,'testq@gmail.com',9,3,'accepted','2026-07-29 04:58:25','2026-07-31 08:49:16'),(9,12,10,'test@gmail.com',8,3,'declined','2026-07-29 05:04:22','2026-07-29 08:28:00'),(23,8,8,'hongquy@gmail.com',6,3,'accepted','2026-07-29 08:37:37','2026-07-29 08:38:29'),(24,8,8,'testq@gmail.com',9,3,'accepted','2026-07-29 08:38:00','2026-07-31 08:49:15'),(25,8,8,'hongquy@gmail.com',6,3,'accepted','2026-07-29 08:39:20','2026-07-29 09:53:32'),(26,8,8,'q@gmail.com',10,3,'accepted','2026-07-29 08:39:35','2026-07-31 08:49:32'),(33,16,6,'test@gmail.com',8,3,'accepted','2026-07-31 08:48:16','2026-07-31 08:48:51'),(34,16,6,'q@gmail.com',10,3,'accepted','2026-07-31 08:48:22','2026-07-31 08:49:29'),(35,16,6,'testq@.gmail.com',NULL,3,'pending','2026-07-31 08:48:31',NULL),(36,18,8,'hongquy@gmail.com',6,3,'accepted','2026-08-16 06:48:57','2026-08-16 07:18:44'),(37,19,6,'test@gmail.com',8,3,'accepted','2026-09-13 22:04:48','2026-09-14 10:11:03'),(38,20,11,'hongquy@gmail.com',6,3,'accepted','2026-09-14 03:08:49','2026-09-14 03:09:14'),(39,20,11,'test@gmail.com',8,3,'accepted','2026-09-16 16:03:35','2026-09-16 16:10:20'),(40,21,11,'test@gmail.com',8,3,'accepted','2026-09-16 16:09:54','2026-09-16 16:10:24');
/*!40000 ALTER TABLE `project_invitations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `project_members`
--

DROP TABLE IF EXISTS `project_members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `project_members` (
  `id` int NOT NULL AUTO_INCREMENT,
  `project_id` int NOT NULL,
  `user_id` int NOT NULL,
  `project_role_id` int DEFAULT NULL,
  `joined_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `project_id` (`project_id`),
  KEY `user_id` (`user_id`),
  KEY `project_members_project_role_fk` (`project_role_id`),
  CONSTRAINT `project_members_ibfk_1` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`) ON DELETE CASCADE,
  CONSTRAINT `project_members_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `project_members_project_role_fk` FOREIGN KEY (`project_role_id`) REFERENCES `project_roles` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=51 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `project_members`
--

LOCK TABLES `project_members` WRITE;
/*!40000 ALTER TABLE `project_members` DISABLE KEYS */;
INSERT INTO `project_members` VALUES (16,8,8,1,'2026-07-29 04:10:54'),(20,10,9,1,'2026-07-29 04:50:06'),(21,11,8,1,'2026-07-29 04:53:53'),(22,12,10,1,'2026-07-29 04:57:43'),(25,8,6,3,'2026-07-29 09:53:32'),(26,12,6,3,'2026-07-29 09:53:34'),(29,16,6,1,'2026-07-31 08:42:35'),(30,16,8,2,'2026-07-31 08:48:51'),(34,8,9,3,'2026-07-31 08:49:15'),(35,12,9,3,'2026-07-31 08:49:16'),(36,16,10,3,'2026-07-31 08:49:29'),(38,8,10,3,'2026-07-31 08:49:32'),(39,17,6,1,'2026-08-03 18:28:29'),(40,18,8,1,'2026-08-16 06:40:52'),(41,18,6,3,'2026-08-16 07:18:44'),(42,19,6,1,'2026-09-13 22:04:48'),(43,20,11,1,'2026-09-14 03:02:49'),(44,20,6,3,'2026-09-14 03:09:14'),(45,21,11,1,'2026-09-14 03:15:15'),(46,22,11,1,'2026-09-14 03:17:55'),(47,19,8,3,'2026-09-14 10:11:03'),(48,23,11,1,'2026-09-14 10:43:19'),(49,20,8,3,'2026-09-16 16:10:20'),(50,21,8,2,'2026-09-16 16:10:24');
/*!40000 ALTER TABLE `project_members` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `project_messages`
--

DROP TABLE IF EXISTS `project_messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `project_messages` (
  `id` int NOT NULL AUTO_INCREMENT,
  `project_id` int NOT NULL,
  `sender_id` int NOT NULL,
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `message_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'text',
  `file_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `file_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `file_size` int DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_project_messages_project_id` (`project_id`),
  KEY `idx_project_messages_sender_id` (`sender_id`),
  KEY `idx_project_messages_created_at` (`created_at`),
  CONSTRAINT `project_messages_project_fk` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`) ON DELETE CASCADE,
  CONSTRAINT `project_messages_sender_fk` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `project_messages`
--

LOCK TABLES `project_messages` WRITE;
/*!40000 ALTER TABLE `project_messages` DISABLE KEYS */;
INSERT INTO `project_messages` VALUES (1,17,6,'hello','text',NULL,NULL,NULL,'2026-08-05 05:08:19','2026-08-05 05:08:19',NULL),(2,8,6,'hello','text',NULL,NULL,NULL,'2026-08-05 05:08:46','2026-08-05 05:08:46',NULL),(3,8,8,'hii','text',NULL,NULL,NULL,'2026-08-05 05:09:13','2026-08-05 05:09:13',NULL),(4,21,11,'chào mọi người','text',NULL,NULL,NULL,'2026-09-16 16:07:07','2026-09-16 16:07:07',NULL);
/*!40000 ALTER TABLE `project_messages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `project_roles`
--

DROP TABLE IF EXISTS `project_roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `project_roles` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `project_roles`
--

LOCK TABLES `project_roles` WRITE;
/*!40000 ALTER TABLE `project_roles` DISABLE KEYS */;
INSERT INTO `project_roles` VALUES (2,'Phó nhóm'),(3,'Thành viên'),(1,'Trưởng nhóm');
/*!40000 ALTER TABLE `project_roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `projects`
--

DROP TABLE IF EXISTS `projects`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `projects` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `owner_id` int NOT NULL,
  `status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'planning',
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `completed_at` datetime DEFAULT NULL,
  `completed_by` int DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `owner_id` (`owner_id`),
  KEY `projects_completed_by_fk` (`completed_by`),
  CONSTRAINT `projects_completed_by_fk` FOREIGN KEY (`completed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `projects_ibfk_1` FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `projects`
--

LOCK TABLES `projects` WRITE;
/*!40000 ALTER TABLE `projects` DISABLE KEYS */;
INSERT INTO `projects` VALUES (8,'ád','zuop',8,'completed','2026-07-29','2026-07-31',NULL,NULL,'2026-07-29 04:10:54','2026-08-11 02:44:11'),(10,'tt55zz','ttfgvb',9,'planning','2026-07-29','2026-07-31',NULL,NULL,'2026-07-29 04:50:06','2026-07-29 04:50:06'),(11,'qwerzop','dfhkk',8,'completed','2026-07-29','2026-07-31',NULL,NULL,'2026-07-29 04:53:53','2026-08-11 02:44:01'),(12,'tk q','qqq',10,'planning','2026-07-29','2026-07-31',NULL,NULL,'2026-07-29 04:57:43','2026-07-29 04:57:43'),(16,'Lập trình di động','Xây dựng ứng dụng di động để quản lý dự án.',6,'planning','2026-07-31',NULL,NULL,NULL,'2026-07-31 08:42:35','2026-07-31 08:42:35'),(17,'sinh nhật thu','tạo những thứ hoàn toàn snvv',6,'completed','2026-08-03',NULL,'2026-08-12 03:11:17',6,'2026-08-03 18:28:29','2026-08-12 03:11:17'),(18,'td ftvv','tx c t cy g y',8,'planning','2026-08-16',NULL,NULL,NULL,'2026-08-16 06:40:51','2026-08-16 06:40:51'),(19,'test','gybny',6,'planning','2026-09-13',NULL,NULL,NULL,'2026-09-13 22:04:48','2026-09-13 22:04:48'),(20,'Lập trình mobile','xây dựng ứng dụng \"Quản lý dự án\" theo môn học lập trình trên thiết bị di động',11,'completed','2026-09-14','2026-09-26','2026-09-16 16:06:55',11,'2026-09-14 03:02:49','2026-09-16 16:06:55'),(21,'Lập trình web','thiết kế website',11,'planning','2026-09-14',NULL,NULL,NULL,'2026-09-14 03:15:15','2026-09-14 03:15:15'),(22,'Web bán hàng','bân máy tính',11,'completed','2026-09-14',NULL,'2026-09-14 03:19:08',11,'2026-09-14 03:17:55','2026-09-14 03:19:08'),(23,'áhggg','hhhh',11,'planning','2026-09-14',NULL,NULL,NULL,'2026-09-14 10:43:19','2026-09-14 10:43:19');
/*!40000 ALTER TABLE `projects` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `registration_otps`
--

DROP TABLE IF EXISTS `registration_otps`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `registration_otps` (
  `id` int NOT NULL AUTO_INCREMENT,
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `password_hash` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `system_role_id` int DEFAULT NULL,
  `otp_hash` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `expires_at` bigint NOT NULL,
  `attempts` int NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_registration_otps_email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `registration_otps`
--

LOCK TABLES `registration_otps` WRITE;
/*!40000 ALTER TABLE `registration_otps` DISABLE KEYS */;
/*!40000 ALTER TABLE `registration_otps` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `roles`
--

DROP TABLE IF EXISTS `roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `roles` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `roles`
--

LOCK TABLES `roles` WRITE;
/*!40000 ALTER TABLE `roles` DISABLE KEYS */;
INSERT INTO `roles` VALUES (1,'Admin'),(2,'Member');
/*!40000 ALTER TABLE `roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `task_assignees`
--

DROP TABLE IF EXISTS `task_assignees`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `task_assignees` (
  `task_id` int NOT NULL,
  `user_id` int NOT NULL,
  `assigned_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`task_id`,`user_id`),
  KEY `task_assignees_user_idx` (`user_id`),
  CONSTRAINT `task_assignees_task_fk` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE,
  CONSTRAINT `task_assignees_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `task_assignees`
--

LOCK TABLES `task_assignees` WRITE;
/*!40000 ALTER TABLE `task_assignees` DISABLE KEYS */;
INSERT INTO `task_assignees` VALUES (17,8,'2026-07-29 00:28:39'),(32,6,'2026-08-03 11:25:53'),(34,6,'2026-08-03 11:29:25'),(35,6,'2026-08-03 11:30:33'),(37,6,'2026-08-11 20:19:47'),(38,10,'2026-08-11 22:30:49'),(39,6,'2026-08-11 23:03:03'),(40,8,'2026-08-15 23:32:12'),(41,8,'2026-08-16 00:16:43'),(42,6,'2026-09-13 15:10:21'),(43,6,'2026-09-13 15:11:24'),(44,6,'2026-09-13 17:32:21'),(45,6,'2026-09-13 17:34:54'),(46,11,'2026-09-13 20:05:06'),(47,11,'2026-09-13 20:06:19'),(48,6,'2026-09-13 20:10:26'),(53,11,'2026-09-16 09:04:31');
/*!40000 ALTER TABLE `task_assignees` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `task_attachments`
--

DROP TABLE IF EXISTS `task_attachments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `task_attachments` (
  `id` int NOT NULL AUTO_INCREMENT,
  `task_id` int NOT NULL,
  `uploader_id` int DEFAULT NULL,
  `file_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `file_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `file_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'document',
  `mime_type` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `file_size` bigint DEFAULT NULL,
  `attachment_scope` enum('task','submission') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'task',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `task_id` (`task_id`),
  KEY `uploader_id` (`uploader_id`),
  CONSTRAINT `task_attachments_task_fk` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE,
  CONSTRAINT `task_attachments_uploader_fk` FOREIGN KEY (`uploader_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `task_attachments`
--

LOCK TABLES `task_attachments` WRITE;
/*!40000 ALTER TABLE `task_attachments` DISABLE KEYS */;
INSERT INTO `task_attachments` VALUES (14,19,8,'Screenshot_20260811_035646.jpg','/upload/file/1786396890106_103474265_Screenshot_20260811_035646.jpg','image',NULL,271324,'task','2026-08-11 04:21:30'),(15,37,6,'IMG_20260812_042831.jpg','/upload/file/1786488122776_55022119_IMG_20260812_042831.jpg','image',NULL,38187,'task','2026-08-12 05:42:02'),(16,39,6,'1346.jpg','/data/user/0/com.example.quanlyduan/cache/026586a5-598d-46c7-b974-1625304f11f7/1346.jpg','image',NULL,251557,'submission','2026-08-12 06:03:03'),(17,39,6,'923.mp4','/data/user/0/com.example.quanlyduan/cache/d0941a98-05c9-4e47-aa58-b5d3509a5dbd/923.mp4','video',NULL,17571010,'submission','2026-08-12 06:03:03'),(18,40,8,'1456.jpg','/data/user/0/com.example.quanlyduan/cache/367157aa-28f8-4344-b1d4-e69cb402725f/1456.jpg','image',NULL,330400,'task','2026-08-16 06:32:12'),(19,40,8,'1463.jpg','/data/user/0/com.example.quanlyduan/cache/6d78b6fc-e8b1-42ec-9b1c-d935f1dfc3e7/1463.jpg','image',NULL,418072,'task','2026-08-16 06:32:12'),(20,40,8,'CV_Pham_Hong_Sang (3).docx','/data/user/0/com.example.quanlyduan/cache/file_picker/1786836720958/CV_Pham_Hong_Sang (3).docx','document',NULL,1598143,'task','2026-08-16 06:32:12'),(21,41,8,'1786802249026.jpg','/upload/file/1786839416858_873891143_1786802249026.jpg','image',NULL,1141595,'submission','2026-08-16 07:16:56'),(22,53,11,'1000028532.webp','/upload/file/1789549471097_272227534_1000028532.webp','image',NULL,41056,'task','2026-09-16 16:04:31');
/*!40000 ALTER TABLE `task_attachments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `task_comments`
--

DROP TABLE IF EXISTS `task_comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `task_comments` (
  `id` int NOT NULL AUTO_INCREMENT,
  `task_id` int NOT NULL,
  `user_id` int NOT NULL,
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `task_id` (`task_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `task_comments_task_fk` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE,
  CONSTRAINT `task_comments_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `task_comments`
--

LOCK TABLES `task_comments` WRITE;
/*!40000 ALTER TABLE `task_comments` DISABLE KEYS */;
INSERT INTO `task_comments` VALUES (9,53,11,'cố gắng hoàn thành','2026-09-16 16:04:57');
/*!40000 ALTER TABLE `task_comments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `task_subtasks`
--

DROP TABLE IF EXISTS `task_subtasks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `task_subtasks` (
  `id` int NOT NULL AUTO_INCREMENT,
  `task_id` int NOT NULL,
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_completed` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `task_id` (`task_id`),
  CONSTRAINT `task_subtasks_ibfk_1` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=28 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `task_subtasks`
--

LOCK TABLES `task_subtasks` WRITE;
/*!40000 ALTER TABLE `task_subtasks` DISABLE KEYS */;
INSERT INTO `task_subtasks` VALUES (19,32,'fh',1,'2026-08-03 18:26:51','2026-08-03 18:26:56'),(20,39,'uhnnhu',0,'2026-08-12 06:03:03','2026-08-12 06:03:03'),(21,39,'yg. hu hu',0,'2026-08-12 06:03:03','2026-08-12 06:03:03'),(22,39,'hb7ubhihu',0,'2026-08-12 06:03:03','2026-08-12 06:03:03'),(23,40,'hbu',0,'2026-08-16 06:32:12','2026-08-16 06:32:12'),(24,40,'gvybhb hub',0,'2026-08-16 06:32:12','2026-08-16 06:32:12'),(25,40,'ggv6h uuv',0,'2026-08-16 06:32:12','2026-08-16 06:32:12'),(26,46,'test đăng nhập',0,'2026-09-14 03:05:06','2026-09-14 03:05:06'),(27,46,'đăng ký',0,'2026-09-14 03:05:06','2026-09-14 03:05:06');
/*!40000 ALTER TABLE `task_subtasks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tasks`
--

DROP TABLE IF EXISTS `tasks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tasks` (
  `id` int NOT NULL AUTO_INCREMENT,
  `project_id` int NOT NULL,
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `assignee_id` int DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `due_date` date DEFAULT NULL,
  `status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'todo',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `project_id` (`project_id`),
  KEY `assignee_id` (`assignee_id`),
  CONSTRAINT `tasks_ibfk_1` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`) ON DELETE CASCADE,
  CONSTRAINT `tasks_ibfk_2` FOREIGN KEY (`assignee_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=54 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tasks`
--

LOCK TABLES `tasks` WRITE;
/*!40000 ALTER TABLE `tasks` DISABLE KEYS */;
INSERT INTO `tasks` VALUES (16,11,'ts1','zz',NULL,NULL,'2026-08-21','todo','2026-07-29 07:28:11','2026-07-29 07:28:11'),(17,11,'ts2','bts',8,NULL,'2026-08-03','todo','2026-07-29 07:28:39','2026-07-29 07:28:39'),(18,11,'ts3',NULL,NULL,NULL,'2026-07-31','todo','2026-07-29 07:29:08','2026-07-29 07:29:08'),(19,11,'rti',NULL,NULL,NULL,'2026-07-31','todo','2026-07-29 07:31:50','2026-07-29 07:31:50'),(31,16,'hhhh','task team',NULL,'2026-08-03','2026-08-07','done','2026-08-03 18:25:18','2026-08-11 04:43:01'),(32,16,'h088','no',6,'2026-08-03','2026-08-07','done','2026-08-03 18:25:53','2026-08-11 04:42:04'),(33,17,'mua bánh kem',NULL,NULL,'2026-08-07','2026-08-07','todo','2026-08-03 18:29:00','2026-08-03 18:29:00'),(34,17,'mua bánh kẹo',NULL,6,'2026-08-06','2026-08-07','todo','2026-08-03 18:29:25','2026-08-03 18:29:25'),(35,17,'mua váy tặng sn',NULL,6,'2026-08-03','2026-08-07','done','2026-08-03 18:30:33','2026-08-11 04:46:42'),(37,16,'jtxhzfkgzgxk','96e8dkgx',6,NULL,'2026-08-21','todo','2026-08-12 03:19:47','2026-08-12 03:19:47'),(38,16,'xũigoyf','uitx',10,NULL,'2026-08-29','todo','2026-08-12 05:30:49','2026-08-12 05:30:49'),(39,16,'ctx vg66b','6bbhbuhnu nj8',6,'2026-08-13','2026-08-15','todo','2026-08-12 06:03:03','2026-08-12 06:05:06'),(40,16,'f yv y','rc5 cgvg',8,NULL,'2026-08-20','in_progress','2026-08-16 06:32:12','2026-08-16 06:32:27'),(41,16,'hhhhj','7hhjjjj',8,NULL,'2026-08-28','done','2026-08-16 07:16:43','2026-08-16 07:17:01'),(42,19,'test1',NULL,6,NULL,'2026-09-18','done','2026-09-13 22:10:21','2026-09-13 22:11:07'),(43,19,'test 2','igcg',6,NULL,NULL,'done','2026-09-13 22:11:24','2026-09-14 00:32:06'),(44,19,'test 3','lâng thứ 3',6,NULL,NULL,'done','2026-09-14 00:32:21','2026-09-14 00:34:25'),(45,19,'test 4','test thông báo',6,NULL,NULL,'todo','2026-09-14 00:34:54','2026-09-14 00:34:54'),(46,20,'Kiểm thử chức năng','kiểm thử các chức năng trên ứng dụng',11,'2026-09-14','2026-09-22','todo','2026-09-14 03:05:06','2026-09-14 03:05:06'),(47,20,'FE Xây dựng giao diện','xây dựng giao diện cho ứng dụng',11,NULL,'2026-09-16','todo','2026-09-14 03:06:19','2026-09-14 03:06:19'),(48,20,'BE xây dựng API','thiết kế API cho app',6,NULL,'2026-09-18','todo','2026-09-14 03:10:26','2026-09-14 03:10:26'),(49,20,'DB thiết kế database','thiết kế cơ sở dữ liệu cho dự án',NULL,NULL,'2026-09-20','in_progress','2026-09-14 03:11:04','2026-09-16 15:52:44'),(50,22,'kiểm thưe chức năng',NULL,NULL,NULL,NULL,'done','2026-09-14 03:18:58','2026-09-14 03:19:03'),(51,20,'test 1',NULL,NULL,NULL,'2026-09-30','done','2026-09-14 10:19:38','2026-09-14 10:19:44'),(52,23,'úudvvv','jhv',NULL,NULL,'2026-09-24','todo','2026-09-14 10:44:25','2026-09-14 10:44:25'),(53,20,'test app','test ứng dựng',11,'2026-09-17','2026-09-30','todo','2026-09-16 16:04:31','2026-09-16 16:04:31');
/*!40000 ALTER TABLE `tasks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_push_tokens`
--

DROP TABLE IF EXISTS `user_push_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_push_tokens` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `token` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `platform` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `device_id` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_push_tokens_token_unique` (`token`),
  KEY `user_push_tokens_user_idx` (`user_id`),
  CONSTRAINT `user_push_tokens_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=40 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_push_tokens`
--

LOCK TABLES `user_push_tokens` WRITE;
/*!40000 ALTER TABLE `user_push_tokens` DISABLE KEYS */;
INSERT INTO `user_push_tokens` VALUES (24,8,'eQBAmvNJQmS4cAitkUrDrl:APA91bG74ZCQDBdsh-PxeGR2yPWUbZD8AczpPz8Z5s_9S5_xJ3_NfZgHh78u2vFk_Wo5Dyu63lU_DK9bNs-sqabhUuG-xtIS4Tnmtvhp47q96tvVrCVTDr0','android',NULL,0,'2026-09-14 10:10:52','2026-09-16 16:07:15'),(34,11,'dipBMnAAQJCJ0aCXTOlYek:APA91bGJdJW3lka5pIlXfRugl18zNfREaD3Sn9-keIk9dEj2NNYgJw01jEbcJATITd0HLL0roZxB9f66rMVWGS6St6v60bF7sKRII8SiKc7DutKoZ94gUIw','android',NULL,1,'2026-09-16 16:02:28','2026-09-16 16:10:51');
/*!40000 ALTER TABLE `user_push_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `avatar` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `birthday` date DEFAULT NULL,
  `address` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `phone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_login_at` datetime DEFAULT NULL,
  `system_role_id` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  KEY `system_role_id` (`system_role_id`),
  KEY `idx_users_email` (`email`),
  CONSTRAINT `users_ibfk_1` FOREIGN KEY (`system_role_id`) REFERENCES `roles` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'admin@company.com','$2y$10$fakehash123','Quản trị viên',NULL,'1990-01-10','Đại Học Bình Dương, TP. Thủ Dầu Một, Bình Dương','0901000001','2026-07-08 21:27:57','2026-07-10 02:57:16',1),(2,'manager@company.com','$2y$10$fakehash456','Nguyễn Văn An',NULL,'1995-03-15','123 Đường ABC, Quận 1, TP. Hồ Chí Minh','0987654321','2026-07-08 21:27:57','2026-07-08 21:27:57',2),(6,'hongquy@gmail.com','$2b$10$KUIeBaRVhNv8fS9HhUuFS.OHIaUSJqFljE4FxNG1D8AxbkeZzd2by','Phạm Hồng Quý','/upload/avatar/user-6-1786483727901.jpg','2002-07-18','Thuận Giao, TP. Hồ Chí Minh',NULL,'2026-07-08 23:48:06','2026-09-16 16:14:43',1),(7,'kha2000@gmail.com','$2b$10$7Xv7uVjk0zhkMqPJm5QhIuULXTglD6h5kCuz405Udu82ZEQRW2SLG','Nguyễn Văn Kha',NULL,'2000-05-20','Dĩ An, Bình Dương','0912345678','2026-07-17 08:08:29','2026-07-17 08:08:57',2),(8,'test@gmail.com','$2b$10$gsCqWwmw7LkXrLNIjXAONu/NWy1Fqhc5Qe/iVh7aWqdGTJPKPWEIS','Phạm Hồng Sang','/upload/avatar/user-8-1786834869625.jpg','1996-09-08','Thủ Đức, TP. Hồ Chí Minh','0934567890','2026-07-27 01:05:57','2026-09-16 16:10:13',2),(9,'testq@gmail.com','$2b$10$K/WltxjWX2wrxFeKRjhDHOmj0njwpxdY1A6XpPtahMTeCahGCvA/K','Lê Văn C',NULL,'2002-11-22','Thuận An, Bình Dương','0945678901','2026-07-29 04:12:58','2026-07-31 08:49:11',2),(10,'q@gmail.com','$2b$10$H.aVX.Ty0Agbt5iH8akSOufM2LjQr1wRVkGvb2RKIGxaOuNfjv9Sy','Phạm Thị D',NULL,'1999-12-05','Quận 9, TP. Hồ Chí Minh','0956789012','2026-07-29 04:57:06','2026-07-31 08:49:27',2),(11,'famqi2003@gmail.com','$2b$10$iI92vwDH4v4KcCwVKsjYmuaKfHRcACrGlVKOSLV/YAT9DmswO9bcG','Phạm Hồng Quý','/upload/avatar/user-11-1789330379175.jpg','2003-07-18','Đồng Tháp','0379997387','2026-09-14 03:00:04','2026-09-16 16:10:51',2);
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-09-16 16:19:16
