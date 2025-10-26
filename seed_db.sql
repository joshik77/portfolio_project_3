-- Currency Converter Database Schema and Seed Data
-- PostgreSQL 15+

-- Drop tables if they exist (for clean setup)
DROP TABLE IF EXISTS conversion_history CASCADE;
DROP TABLE IF EXISTS alerts CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Create Users table
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    web_push_subscription TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index on email for faster lookups
CREATE INDEX idx_users_email ON users(email);

-- Create Alerts table
CREATE TABLE alerts (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    base_currency VARCHAR(3) NOT NULL,
    target_currency VARCHAR(3) NOT NULL,
    operator VARCHAR(2) NOT NULL CHECK (operator IN ('<', '>', '<=', '>=')),
    threshold DECIMAL(15, 4) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    last_triggered TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for alerts
CREATE INDEX idx_alerts_user_id ON alerts(user_id);
CREATE INDEX idx_alerts_enabled ON alerts(enabled);
CREATE INDEX idx_alerts_currencies ON alerts(base_currency, target_currency);

-- Create Conversion History table
CREATE TABLE conversion_history (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    from_currency VARCHAR(3) NOT NULL,
    to_currency VARCHAR(3) NOT NULL,
    amount DECIMAL(15, 4) NOT NULL,
    rate DECIMAL(15, 6) NOT NULL,
    result DECIMAL(15, 4) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for conversion history
CREATE INDEX idx_conversion_history_user_id ON conversion_history(user_id);
CREATE INDEX idx_conversion_history_created_at ON conversion_history(created_at DESC);
CREATE INDEX idx_conversion_history_currencies ON conversion_history(from_currency, to_currency);

-- Create Refresh Tokens table (for JWT refresh)
CREATE TABLE refresh_tokens (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(512) UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_token ON refresh_tokens(token);

-- Create Alert History table (to track triggered alerts)
CREATE TABLE alert_history (
    id BIGSERIAL PRIMARY KEY,
    alert_id BIGINT NOT NULL REFERENCES alerts(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    triggered_rate DECIMAL(15, 6) NOT NULL,
    message TEXT,
    triggered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_alert_history_alert_id ON alert_history(alert_id);
CREATE INDEX idx_alert_history_user_id ON alert_history(user_id);

-- Create User Preferences table
CREATE TABLE user_preferences (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    default_base_currency VARCHAR(3) DEFAULT 'USD',
    default_target_currency VARCHAR(3) DEFAULT 'INR',
    notification_enabled BOOLEAN DEFAULT TRUE,
    email_notifications BOOLEAN DEFAULT TRUE,
    push_notifications BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_preferences_user_id ON user_preferences(user_id);

-- ============================================
-- SEED DATA
-- ============================================

-- Insert test users (password is 'password123' - BCrypt hashed)
-- Use BCrypt hash: $2a$10$YourHashHere (you should generate this properly)
INSERT INTO users (email, password, name, created_at) VALUES
    ('demo@example.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Demo User', NOW()),
    ('john@example.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'John Doe', NOW()),
    ('jane@example.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Jane Smith', NOW());

-- Insert sample alerts for demo user
INSERT INTO alerts (user_id, base_currency, target_currency, operator, threshold, enabled, created_at) VALUES
    (1, 'USD', 'INR', '<', 80.00, TRUE, NOW()),
    (1, 'EUR', 'USD', '>', 1.10, TRUE, NOW()),
    (1, 'GBP', 'USD', '<', 1.25, FALSE, NOW()),
    (2, 'USD', 'JPY', '>', 150.00, TRUE, NOW()),
    (2, 'USD', 'EUR', '<', 0.95, TRUE, NOW());

-- Insert sample conversion history
INSERT INTO conversion_history (user_id, from_currency, to_currency, amount, rate, result, created_at) VALUES
    (1, 'USD', 'INR', 100.00, 83.4000, 8340.00, NOW() - INTERVAL '1 day'),
    (1, 'EUR', 'USD', 50.00, 1.0850, 54.25, NOW() - INTERVAL '2 days'),
    (1, 'USD', 'GBP', 200.00, 0.7900, 158.00, NOW() - INTERVAL '3 days'),
    (2, 'USD', 'JPY', 1000.00, 149.5000, 149500.00, NOW() - INTERVAL '1 day'),
    (2, 'GBP', 'EUR', 75.00, 1.1600, 87.00, NOW() - INTERVAL '5 days'),
    (3, 'USD', 'CAD', 500.00, 1.3600, 680.00, NOW() - INTERVAL '1 hour');

-- Insert user preferences
INSERT INTO user_preferences (user_id, default_base_currency, default_target_currency) VALUES
    (1, 'USD', 'INR'),
    (2, 'EUR', 'USD'),
    (3, 'GBP', 'EUR');

-- ============================================
-- FUNCTIONS AND TRIGGERS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for users table
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger for user_preferences table
CREATE TRIGGER update_user_preferences_updated_at
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- VIEWS FOR REPORTING
-- ============================================

-- View for user statistics
CREATE OR REPLACE VIEW user_statistics AS
SELECT 
    u.id,
    u.email,
    u.name,
    COUNT(DISTINCT ch.id) as total_conversions,
    COUNT(DISTINCT a.id) as total_alerts,
    COUNT(DISTINCT CASE WHEN a.enabled = TRUE THEN a.id END) as active_alerts,
    MAX(ch.created_at) as last_conversion_at,
    u.created_at as user_since
FROM users u
LEFT JOIN conversion_history ch ON u.id = ch.user_id
LEFT JOIN alerts a ON u.id = a.user_id
GROUP BY u.id, u.email, u.name, u.created_at;

-- View for popular currency pairs
CREATE OR REPLACE VIEW popular_currency_pairs AS
SELECT 
    from_currency,
    to_currency,
    COUNT(*) as conversion_count,
    AVG(rate) as avg_rate,
    MIN(rate) as min_rate,
    MAX(rate) as max_rate,
    MAX(created_at) as last_conversion_at
FROM conversion_history
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY from_currency, to_currency
ORDER BY conversion_count DESC
LIMIT 20;

-- View for alert effectiveness
CREATE OR REPLACE VIEW alert_effectiveness AS
SELECT 
    a.id as alert_id,
    u.email as user_email,
    a.base_currency,
    a.target_currency,
    a.operator,
    a.threshold,
    a.enabled,
    COUNT(ah.id) as times_triggered,
    MAX(ah.triggered_at) as last_triggered,
    a.created_at as alert_created
FROM alerts a
JOIN users u ON a.user_id = u.id
LEFT JOIN alert_history ah ON a.id = ah.alert_id
GROUP BY a.id, u.email, a.base_currency, a.target_currency, 
         a.operator, a.threshold, a.enabled, a.created_at;

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

-- Grant permissions to application user (if using specific role)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO currencyuser;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO currencyuser;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO currencyuser;

-- ============================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================

COMMENT ON TABLE users IS 'User accounts for the currency converter application';
COMMENT ON TABLE alerts IS 'User-defined currency rate alerts';
COMMENT ON TABLE conversion_history IS 'History of all currency conversions performed';
COMMENT ON TABLE refresh_tokens IS 'JWT refresh tokens for authentication';
COMMENT ON TABLE alert_history IS 'History of triggered alerts';
COMMENT ON TABLE user_preferences IS 'User-specific preferences and settings';

COMMENT ON COLUMN users.web_push_subscription IS 'JSON string containing Web Push subscription details';
COMMENT ON COLUMN alerts.operator IS 'Comparison operator: <, >, <=, >=';
COMMENT ON COLUMN alerts.threshold IS 'Rate threshold that triggers the alert';

-- ============================================
-- SAMPLE QUERIES FOR TESTING
-- ============================================

-- Get all active alerts for a user
-- SELECT * FROM alerts WHERE user_id = 1 AND enabled = TRUE;

-- Get recent conversion history
-- SELECT * FROM conversion_history WHERE user_id = 1 ORDER BY created_at DESC LIMIT 10;

-- Get user statistics
-- SELECT * FROM user_statistics WHERE email = 'demo@example.com';

-- Get popular currency pairs
-- SELECT * FROM popular_currency_pairs;

-- ============================================
-- DATABASE MAINTENANCE
-- ============================================

-- Clean up old conversion history (optional, run periodically)
-- DELETE FROM conversion_history WHERE created_at < NOW() - INTERVAL '1 year';

-- Clean up expired refresh tokens
-- DELETE FROM refresh_tokens WHERE expires_at < NOW();

-- Vacuum and analyze for performance
-- VACUUM ANALYZE;

-- ============================================
-- COMPLETION MESSAGE
-- ============================================

DO $$
BEGIN
    RAISE NOTICE 'Database schema and seed data loaded successfully!';
    RAISE NOTICE 'Test users created:';
    RAISE NOTICE '  - demo@example.com / password123';
    RAISE NOTICE '  - john@example.com / password123';
    RAISE NOTICE '  - jane@example.com / password123';
END $$;