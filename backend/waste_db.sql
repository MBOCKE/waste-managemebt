-- ============================================
-- WASTE MANAGEMENT SYSTEM DATABASE
-- WITH UUID PRIMARY KEYS AND POSTGIS
-- ============================================

-- First, ensure extensions are enabled
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- CREATE ENUM TYPES FOR DATA INTEGRITY
-- ============================================

-- User roles and status
CREATE TYPE user_role AS ENUM ('user', 'driver', 'admin');
CREATE TYPE user_status AS ENUM ('pending', 'active', 'suspended', 'inactive');

-- Bin and waste types
CREATE TYPE waste_type AS ENUM ('general', 'recyclable', 'organic', 'hazardous');
CREATE TYPE fill_level AS ENUM ('empty', 'quarter', 'half', 'three_quarters', 'full');

-- Fleet and operational types
CREATE TYPE truck_status AS ENUM ('available', 'on_route', 'maintenance', 'out_of_service');
CREATE TYPE fuel_type AS ENUM ('diesel', 'petrol', 'electric', 'hybrid', 'cng');
CREATE TYPE route_status AS ENUM ('pending', 'assigned', 'in_progress', 'completed', 'cancelled');
CREATE TYPE notification_status AS ENUM ('sent', 'delivered', 'read', 'failed');

-- ============================================
-- CREATE TABLES IN DEPENDENCY ORDER
-- ============================================

-- 1. USERS TABLE - Foundation of the system
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Authentication fields
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    
    -- Role and permissions
    role user_role DEFAULT 'user',
    status user_status DEFAULT 'pending',
    
    -- Personal/Organization details
    full_name VARCHAR(255),
    phone VARCHAR(9),
    establishment_name VARCHAR(200),
    address TEXT,
    
    -- Location (PostGIS Point geometry)
    location GEOMETRY(Point, 4326),  -- SRID 4326 = WGS84 (GPS coordinates)
    
    -- Notification preferences
    reminder_time TIME DEFAULT '07:30:00',
    wants_daily_reminder BOOLEAN DEFAULT TRUE,
    notification_token TEXT,  -- For push notifications
    
    -- Timestamps and soft delete
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'  -- For flexible additional data
);

-- 2. BINS TABLE - Waste containers at user locations
CREATE TABLE bins (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Bin identification
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) UNIQUE,  -- Human-readable code (BIN-001, etc.)
    qr_code UUID DEFAULT uuid_generate_v4(),  -- For QR generation
    
    -- Physical characteristics
    capacity_liters INTEGER NOT NULL CHECK (capacity_liters > 0),
    waste_type waste_type DEFAULT 'general',
    
    -- Location (PostGIS Point)
    location GEOMETRY(Point, 4326) NOT NULL,
    address TEXT,
    
    -- Current status
    current_fill_level fill_level DEFAULT 'empty',
    last_reported TIMESTAMP WITH TIME ZONE,
    needs_collection BOOLEAN DEFAULT FALSE,
    
    -- Operational flags
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    -- Constraints
    CONSTRAINT valid_capacity CHECK (capacity_liters BETWEEN 1 AND 10000)
);

-- 3. WASTE REPORTS TABLE - Historical record of waste levels
CREATE TABLE waste_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    bin_id UUID NOT NULL REFERENCES bins(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Report data
    fill_level fill_level NOT NULL,
    notes TEXT,
    photo_url VARCHAR(500),
    
    -- Metadata
    reported_via VARCHAR(50) DEFAULT 'app',
    device_info JSONB DEFAULT '{}',
    
    -- Timestamp
    reported_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Prevent duplicate reports within the same second
    CONSTRAINT unique_bin_report UNIQUE(bin_id, reported_at)
);

-- 4. TRUCKS TABLE - Collection vehicles
CREATE TABLE trucks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identification
    license_plate VARCHAR(20) UNIQUE NOT NULL,
    model VARCHAR(100),
    vin VARCHAR(50) UNIQUE,  -- Vehicle Identification Number
    
    -- Specifications
    capacity_kg INTEGER NOT NULL CHECK (capacity_kg > 0),
    year INTEGER CHECK (year BETWEEN 1990 AND EXTRACT(YEAR FROM CURRENT_DATE) + 1),
    fuel_type fuel_type DEFAULT 'diesel',
    
    -- Current assignment (One-to-one with driver)
    current_driver_id UUID UNIQUE REFERENCES users(id) ON DELETE SET NULL,
    
    -- Status and location
    status truck_status DEFAULT 'available',
    last_location GEOMETRY(Point, 4326),
    last_location_update TIMESTAMP WITH TIME ZONE,
    
    -- Operational metrics
    total_distance_km DECIMAL(10, 2) DEFAULT 0,
    last_maintenance_date DATE,
    next_maintenance_date DATE,
    
    -- Additional info
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    retired_at TIMESTAMP WITH TIME ZONE
);

-- 5. DRIVER PROFILES TABLE - Extended driver information
CREATE TABLE driver_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- Professional information
    license_number VARCHAR(50) UNIQUE NOT NULL,
    license_expiry DATE,
    
    -- Current assignment (One-to-one with truck)
    current_truck_id UUID UNIQUE REFERENCES trucks(id) ON DELETE SET NULL,
    
    -- Location tracking preferences
    location_sharing_enabled BOOLEAN DEFAULT FALSE,
    location_update_frequency INTEGER DEFAULT 30 CHECK (location_update_frequency BETWEEN 10 AND 300),
    
    -- Device information
    device_model VARCHAR(100),
    device_os VARCHAR(50),
    app_version VARCHAR(20),
    
    -- Status
    is_on_duty BOOLEAN DEFAULT FALSE,
    last_active TIMESTAMP WITH TIME ZONE,
    
    -- Emergency contacts
    emergency_contact_name VARCHAR(100),
    emergency_contact_phone VARCHAR(20),
    
    -- Additional details
    hire_date DATE DEFAULT CURRENT_DATE,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. LOCATION UPDATES TABLE - GPS tracking history
CREATE TABLE location_updates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Location data (PostGIS Point)
    location GEOMETRY(Point, 4326) NOT NULL,
    accuracy_meters DECIMAL(5, 2) CHECK (accuracy_meters >= 0),
    altitude DECIMAL(8, 2),
    heading DECIMAL(5, 2) CHECK (heading >= 0 AND heading <= 360),
    
    -- Device information
    battery_level INTEGER CHECK (battery_level BETWEEN 0 AND 100),
    network_type VARCHAR(20),
    device_speed_kmh DECIMAL(5, 2) CHECK (device_speed_kmh >= 0),
    
    -- Timestamp
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Changed: Regular date column (will be populated by trigger)
    recorded_date DATE
);

-- 7. COLLECTION ROUTES TABLE - Planned collection paths
CREATE TABLE collection_routes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Assignment
    driver_id UUID REFERENCES users(id) ON DELETE SET NULL,
    truck_id UUID REFERENCES trucks(id) ON DELETE SET NULL,
    
    -- Route details
    name VARCHAR(200),
    code VARCHAR(50) UNIQUE,  -- Human-readable (RT-2023-001)
    scheduled_date DATE NOT NULL,
    scheduled_start_time TIME,
    scheduled_end_time TIME,
    
    -- Route optimization data (GeoJSON LineString)
    optimized_path JSONB,
    total_distance_km DECIMAL(7, 2),
    estimated_duration_minutes INTEGER,
    
    -- Actual execution
    actual_start_time TIMESTAMP WITH TIME ZONE,
    actual_end_time TIMESTAMP WITH TIME ZONE,
    actual_distance_km DECIMAL(7, 2),
    
    -- Status and metrics
    status route_status DEFAULT 'pending',
    bins_collected INTEGER DEFAULT 0,
    total_waste_kg DECIMAL(8, 2) DEFAULT 0,
    efficiency_score DECIMAL(5, 2) CHECK (efficiency_score >= 0 AND efficiency_score <= 100),
    
    -- Creator information
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE
);

-- 8. ROUTE BINS JUNCTION TABLE - Bins assigned to routes
CREATE TABLE route_bins (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id UUID NOT NULL REFERENCES collection_routes(id) ON DELETE CASCADE,
    bin_id UUID NOT NULL REFERENCES bins(id) ON DELETE CASCADE,
    
    -- Collection order and status
    sequence_number INTEGER NOT NULL,
    collected BOOLEAN DEFAULT FALSE,
    collected_at TIMESTAMP WITH TIME ZONE,
    weight_kg DECIMAL(6, 2) CHECK (weight_kg >= 0),
    
    -- Notes and metadata
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    
    -- Constraints for data integrity
    UNIQUE(route_id, bin_id),
    UNIQUE(route_id, sequence_number),
    
    -- Ensure sequence starts at 1
    CHECK (sequence_number > 0)
);

-- 9. NOTIFICATIONS TABLE - Push notification history
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Notification content
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    notification_type VARCHAR(50),
    
    -- Delivery status
    status notification_status DEFAULT 'sent',
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    delivered_at TIMESTAMP WITH TIME ZONE,
    read_at TIMESTAMP WITH TIME ZONE,
    
    -- Action data
    action_url VARCHAR(500),
    action_data JSONB DEFAULT '{}',
    
    -- Metadata
    device_token TEXT,
    error_message TEXT
);

-- 10. AUDIT LOG TABLE - System activity tracking
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Who performed the action
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- What action was performed
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50),
    entity_id UUID,
    
    -- What changed
    old_values JSONB,
    new_values JSONB,
    
    -- Context
    ip_address INET,
    user_agent TEXT,
    
    -- Timestamp
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Changed: Regular date column (will be populated by trigger)
    action_date DATE
);

-- ============================================
-- CREATE FUNCTIONS AND TRIGGERS
-- ============================================

-- Function to set date columns for location_updates and audit_log
CREATE OR REPLACE FUNCTION set_date_columns()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_TABLE_NAME = 'location_updates' THEN
        NEW.recorded_date := DATE(NEW.recorded_at);
    ELSIF TG_TABLE_NAME = 'audit_log' THEN
        NEW.action_date := DATE(NEW.created_at);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update updated_at timestamp automatically
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update bin collection flag based on fill level
CREATE OR REPLACE FUNCTION update_bin_collection_flag()
RETURNS TRIGGER AS $$
BEGIN
    -- Mark bin as needing collection if 75% or more full
    IF NEW.current_fill_level IN ('three_quarters', 'full') THEN
        NEW.needs_collection = TRUE;
    ELSE
        NEW.needs_collection = FALSE;
    END IF;
    
    -- Update last_reported timestamp
    NEW.last_reported = CURRENT_TIMESTAMP;
    NEW.updated_at = CURRENT_TIMESTAMP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update truck location when driver updates location
CREATE OR REPLACE FUNCTION update_truck_location()
RETURNS TRIGGER AS $$
BEGIN
    -- Update truck location if driver has assigned truck
    UPDATE trucks 
    SET last_location = NEW.location,
        last_location_update = NEW.recorded_at
    WHERE current_driver_id = NEW.driver_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update route metrics when bin is collected
CREATE OR REPLACE FUNCTION update_route_metrics()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.collected = TRUE AND OLD.collected = FALSE THEN
        -- Update bins collected count
        UPDATE collection_routes 
        SET bins_collected = bins_collected + 1,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = NEW.route_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function for audit logging
CREATE OR REPLACE FUNCTION audit_log_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        INSERT INTO audit_log (user_id, action, entity_type, entity_id, old_values, new_values)
        VALUES (
            NEW.id,  -- Assuming user_id is in the updated row
            TG_OP,
            TG_TABLE_NAME,
            NEW.id,
            to_jsonb(OLD),
            to_jsonb(NEW)
        );
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO audit_log (user_id, action, entity_type, entity_id, new_values)
        VALUES (
            NEW.id,
            TG_OP,
            TG_TABLE_NAME,
            NEW.id,
            to_jsonb(NEW)
        );
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO audit_log (action, entity_type, entity_id, old_values)
        VALUES (
            TG_OP,
            TG_TABLE_NAME,
            OLD.id,
            to_jsonb(OLD)
        );
    END IF;
    
    RETURN NULL; -- Result is ignored since this is an AFTER trigger
END;
$$ LANGUAGE plpgsql;

-- Apply triggers to tables

-- Date column triggers
CREATE TRIGGER trigger_set_location_date
    BEFORE INSERT ON location_updates
    FOR EACH ROW
    EXECUTE FUNCTION set_date_columns();

CREATE TRIGGER trigger_set_audit_date
    BEFORE INSERT ON audit_log
    FOR EACH ROW
    EXECUTE FUNCTION set_date_columns();

-- Users table triggers
CREATE TRIGGER trigger_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Bins table triggers
CREATE TRIGGER trigger_bins_updated_at 
    BEFORE UPDATE ON bins 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_bin_fill_update 
    BEFORE UPDATE OF current_fill_level ON bins 
    FOR EACH ROW 
    EXECUTE FUNCTION update_bin_collection_flag();

-- Trucks table trigger
CREATE TRIGGER trigger_trucks_updated_at 
    BEFORE UPDATE ON trucks 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Driver profiles trigger
CREATE TRIGGER trigger_driver_profiles_updated_at 
    BEFORE UPDATE ON driver_profiles 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Collection routes trigger
CREATE TRIGGER trigger_collection_routes_updated_at 
    BEFORE UPDATE ON collection_routes 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Location updates trigger (for truck location)
CREATE TRIGGER trigger_location_update 
    AFTER INSERT ON location_updates 
    FOR EACH ROW 
    EXECUTE FUNCTION update_truck_location();

-- Route bins trigger
CREATE TRIGGER trigger_route_bins_collected 
    AFTER UPDATE OF collected ON route_bins 
    FOR EACH ROW 
    EXECUTE FUNCTION update_route_metrics();

-- ============================================
-- CREATE INDEXES FOR PERFORMANCE
-- ============================================

-- USERS table indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role_status ON users(role, status);
CREATE INDEX idx_users_location ON users USING GIST(location);
CREATE INDEX idx_users_created_at ON users(created_at DESC);

-- BINS table indexes
CREATE INDEX idx_bins_user_id ON bins(user_id);
CREATE INDEX idx_bins_location ON bins USING GIST(location);
CREATE INDEX idx_bins_fill_level ON bins(current_fill_level);
CREATE INDEX idx_bins_needs_collection ON bins(needs_collection) WHERE needs_collection = TRUE;
CREATE INDEX idx_bins_active ON bins(is_active) WHERE is_active = TRUE;

-- WASTE REPORTS table indexes
CREATE INDEX idx_waste_reports_bin_id ON waste_reports(bin_id);
CREATE INDEX idx_waste_reports_user_id ON waste_reports(user_id);
CREATE INDEX idx_waste_reports_reported_at ON waste_reports(reported_at DESC);
CREATE INDEX idx_waste_reports_bin_reported ON waste_reports(bin_id, reported_at DESC);

-- TRUCKS table indexes
CREATE INDEX idx_trucks_status ON trucks(status);
CREATE INDEX idx_trucks_driver_id ON trucks(current_driver_id) WHERE current_driver_id IS NOT NULL;
CREATE INDEX idx_trucks_license_plate ON trucks(license_plate);

-- DRIVER PROFILES table indexes
CREATE INDEX idx_driver_profiles_on_duty ON driver_profiles(is_on_duty) WHERE is_on_duty = TRUE;
CREATE INDEX idx_driver_profiles_truck_id ON driver_profiles(current_truck_id) WHERE current_truck_id IS NOT NULL;

-- LOCATION UPDATES table indexes
CREATE INDEX idx_location_updates_driver_id ON location_updates(driver_id);
CREATE INDEX idx_location_updates_recorded_at ON location_updates(recorded_at DESC);
CREATE INDEX idx_location_updates_location ON location_updates USING GIST(location);
CREATE INDEX idx_location_updates_recorded_date ON location_updates(recorded_date);
CREATE INDEX idx_location_updates_driver_date ON location_updates(driver_id, recorded_date);

-- COLLECTION ROUTES table indexes
CREATE INDEX idx_collection_routes_status ON collection_routes(status);
CREATE INDEX idx_collection_routes_driver_id ON collection_routes(driver_id) WHERE driver_id IS NOT NULL;
CREATE INDEX idx_collection_routes_scheduled_date ON collection_routes(scheduled_date);
CREATE INDEX idx_collection_routes_created_at ON collection_routes(created_at DESC);

-- ROUTE BINS table indexes
CREATE INDEX idx_route_bins_route_id ON route_bins(route_id);
CREATE INDEX idx_route_bins_bin_id ON route_bins(bin_id);
CREATE INDEX idx_route_bins_collected ON route_bins(collected) WHERE collected = FALSE;

-- NOTIFICATIONS table indexes
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_status ON notifications(status);
CREATE INDEX idx_notifications_sent_at ON notifications(sent_at DESC);

-- AUDIT LOG table indexes
CREATE INDEX idx_audit_log_user_id ON audit_log(user_id);
CREATE INDEX idx_audit_log_action ON audit_log(action);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at DESC);
CREATE INDEX idx_audit_log_action_date ON audit_log(action_date);

-- ============================================
-- CREATE VIEWS FOR COMMON QUERIES
-- ============================================

-- View for bins needing urgent collection (full for more than 24 hours)
CREATE VIEW bins_urgent_collection AS
SELECT 
    b.id,
    b.name,
    b.code,
    b.current_fill_level,
    b.last_reported,
    b.location,
    u.establishment_name,
    u.address,
    u.phone,
    ST_X(b.location) AS longitude,
    ST_Y(b.location) AS latitude,
    CASE 
        WHEN b.current_fill_level = 'full' AND b.last_reported < NOW() - INTERVAL '24 hours' 
        THEN 'critical'
        WHEN b.current_fill_level = 'full' 
        THEN 'high'
        WHEN b.current_fill_level = 'three_quarters' 
        THEN 'medium'
        ELSE 'low'
    END AS priority
FROM bins b
JOIN users u ON b.user_id = u.id
WHERE b.needs_collection = TRUE 
    AND b.is_active = TRUE
    AND u.status = 'active'
ORDER BY 
    CASE 
        WHEN b.current_fill_level = 'full' AND b.last_reported < NOW() - INTERVAL '24 hours' THEN 1
        WHEN b.current_fill_level = 'full' THEN 2
        WHEN b.current_fill_level = 'three_quarters' THEN 3
        ELSE 4
    END,
    b.last_reported ASC;

-- View for active drivers with current status
CREATE VIEW active_drivers_status AS
SELECT 
    u.id AS user_id,
    u.full_name,
    u.establishment_name,
    u.phone,
    d.license_number,
    t.license_plate,
    t.model AS truck_model,
    d.is_on_duty,
    t.last_location,
    t.last_location_update,
    ST_X(t.last_location) AS longitude,
    ST_Y(t.last_location) AS latitude,
    COALESCE((
        SELECT status 
        FROM collection_routes cr 
        WHERE cr.driver_id = u.id 
            AND cr.scheduled_date = CURRENT_DATE 
            AND cr.status IN ('assigned', 'in_progress')
        LIMIT 1
    ), 'pending') AS current_route_status
FROM users u
JOIN driver_profiles d ON u.id = d.user_id
LEFT JOIN trucks t ON d.current_truck_id = t.id
WHERE u.role = 'driver' 
    AND u.status = 'active'
    AND u.deleted_at IS NULL;

-- View for daily waste reporting statistics
CREATE VIEW daily_waste_stats AS
SELECT 
    DATE(reported_at) AS report_date,
    COUNT(*) AS total_reports,
    COUNT(DISTINCT wr.user_id) AS active_users,
    COUNT(DISTINCT wr.bin_id) AS bins_reported,
    SUM(CASE WHEN wr.fill_level = 'full' THEN 1 ELSE 0 END) AS full_bins,
    SUM(CASE WHEN wr.fill_level = 'three_quarters' THEN 1 ELSE 0 END) AS three_quarter_bins,
    SUM(CASE WHEN wr.fill_level = 'half' THEN 1 ELSE 0 END) AS half_bins,
    SUM(CASE WHEN wr.fill_level = 'quarter' THEN 1 ELSE 0 END) AS quarter_bins
FROM waste_reports wr
JOIN users u ON wr.user_id = u.id
WHERE u.status = 'active'
GROUP BY DATE(reported_at)
ORDER BY report_date DESC;

-- View for route efficiency analysis
CREATE VIEW route_efficiency AS
SELECT 
    cr.id AS route_id,
    cr.code AS route_code,
    cr.scheduled_date,
    cr.status,
    u.full_name AS driver_name,
    t.license_plate,
    cr.bins_collected,
    cr.total_waste_kg,
    cr.estimated_duration_minutes,
    cr.actual_distance_km,
    cr.total_distance_km,
    cr.efficiency_score,
    CASE 
        WHEN cr.actual_distance_km IS NOT NULL AND cr.total_distance_km IS NOT NULL 
        THEN ROUND((cr.total_distance_km / NULLIF(cr.actual_distance_km, 0)) * 100, 2)
        ELSE NULL
    END AS distance_efficiency_percent
FROM collection_routes cr
LEFT JOIN users u ON cr.driver_id = u.id
LEFT JOIN trucks t ON cr.truck_id = t.id
WHERE cr.status IN ('completed', 'in_progress')
ORDER BY cr.scheduled_date DESC;

-- View for user notification preferences
CREATE VIEW user_notification_settings AS
SELECT 
    u.id,
    u.email,
    u.full_name,
    u.establishment_name,
    u.reminder_time,
    u.wants_daily_reminder,
    CASE 
        WHEN u.notification_token IS NOT NULL THEN 'push_enabled'
        ELSE 'push_disabled'
    END AS push_status,
    COUNT(DISTINCT b.id) AS total_bins,
    COUNT(DISTINCT CASE WHEN b.needs_collection = TRUE THEN b.id END) AS bins_needing_collection
FROM users u
LEFT JOIN bins b ON u.id = b.user_id AND b.is_active = TRUE
WHERE u.status = 'active'
    AND u.deleted_at IS NULL
GROUP BY u.id, u.email, u.full_name, u.establishment_name, u.reminder_time, 
         u.wants_daily_reminder, u.notification_token;

-- ============================================
-- CREATE SPATIAL FUNCTIONS FOR ROUTE OPTIMIZATION
-- ============================================

-- Function to find bins within a radius (for route planning)
CREATE OR REPLACE FUNCTION find_bins_near_point(
    center_lat DOUBLE PRECISION,
    center_lng DOUBLE PRECISION,
    radius_meters INTEGER DEFAULT 1000
)
RETURNS TABLE (
    bin_id UUID,
    bin_name VARCHAR,
    fill_level fill_level,
    distance_meters DOUBLE PRECISION,
    establishment_name VARCHAR,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id AS bin_id,
        b.name AS bin_name,
        b.current_fill_level AS fill_level,
        ST_Distance(
            b.location::geography,
            ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography
        ) AS distance_meters,
        u.establishment_name,
        u.address,
        ST_Y(b.location) AS latitude,
        ST_X(b.location) AS longitude
    FROM bins b
    JOIN users u ON b.user_id = u.id
    WHERE b.is_active = TRUE
        AND b.needs_collection = TRUE
        AND u.status = 'active'
        AND ST_DWithin(
            b.location::geography,
            ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography,
            radius_meters
        )
    ORDER BY distance_meters ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate optimal route between points
CREATE OR REPLACE FUNCTION calculate_route_distance(
    points GEOMETRY[]
)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    total_distance DECIMAL(10,2) := 0;
    i INTEGER;
BEGIN
    FOR i IN 1..array_length(points, 1) - 1 LOOP
        total_distance := total_distance + ST_Distance(
            points[i]::geography,
            points[i + 1]::geography
        );
    END LOOP;
    
    RETURN ROUND(total_distance / 1000, 2); -- Convert to kilometers
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- INSERT SAMPLE DATA FOR TESTING
-- ============================================

-- Sample admin user (password: Admin123!)
INSERT INTO users (id, email, username, password_hash, role, status, full_name, establishment_name, address, location)
VALUES (
    '11111111-1111-1111-1111-111111111111',
    'admin@wastemgt.com',
    'admin',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW', -- bcrypt hash for 'Admin123!'
    'admin',
    'active',
    'System Administrator',
    'Waste Management Inc.',
    '123 Admin Street, City',
    ST_SetSRID(ST_MakePoint(-74.0060, 40.7128), 4326)
);

-- Sample restaurant user (password: Restaurant123!)
INSERT INTO users (id, email, username, password_hash, role, status, full_name, establishment_name, address, location)
VALUES (
    '22222222-2222-2222-2222-222222222222',
    'green@restaurant.com',
    'green_restaurant',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',
    'user',
    'active',
    'Green Restaurant Manager',
    'Green Restaurant',
    '456 Food Street, City',
    ST_SetSRID(ST_MakePoint(-74.0080, 40.7130), 4326)
);

-- Sample driver user (password: Driver123!)
INSERT INTO users (id, email, username, password_hash, role, status, full_name, establishment_name, address, location)
VALUES (
    '33333333-3333-3333-3333-333333333333',
    'driver@wastemgt.com',
    'driver_john',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',
    'driver',
    'active',
    'John Driver',
    'Driver Services',
    '789 Driver Lane, City',
    ST_SetSRID(ST_MakePoint(-74.0040, 40.7118), 4326)
);

-- Sample truck
INSERT INTO trucks (id, license_plate, model, capacity_kg, fuel_type, current_driver_id, status, last_location)
VALUES (
    '44444444-4444-4444-4444-444444444444',
    'TRK-001',
    'WasteMaster 5000',
    5000,
    'diesel',
    '33333333-3333-3333-3333-333333333333',
    'available',
    ST_SetSRID(ST_MakePoint(-74.0040, 40.7118), 4326)
);

-- Driver profile
INSERT INTO driver_profiles (user_id, license_number, current_truck_id, location_sharing_enabled, is_on_duty)
VALUES (
    '33333333-3333-3333-3333-333333333333',
    'DL-123456',
    '44444444-4444-4444-4444-444444444444',
    TRUE,
    TRUE
);

-- Sample bins for the restaurant
INSERT INTO bins (id, user_id, name, code, capacity_liters, waste_type, location, current_fill_level, address)
VALUES 
(
    '55555555-5555-5555-5555-555555555555',
    '22222222-2222-2222-2222-222222222222',
    'Main Kitchen Bin',
    'BIN-GR-001',
    120,
    'general',
    ST_SetSRID(ST_MakePoint(-74.0081, 40.7131), 4326),
    'three_quarters',
    'Green Restaurant Backyard'
),
(
    '66666666-6666-6666-6666-666666666666',
    '22222222-2222-2222-2222-222222222222',
    'Recycling Bin',
    'BIN-GR-002',
    80,
    'recyclable',
    ST_SetSRID(ST_MakePoint(-74.0079, 40.7129), 4326),
    'half',
    'Green Restaurant Front'
);

-- Sample waste reports
INSERT INTO waste_reports (id, bin_id, user_id, fill_level, reported_at)
VALUES 
(
    '77777777-7777-7777-7777-777777777777',
    '55555555-5555-5555-5555-555555555555',
    '22222222-2222-2222-2222-222222222222',
    'three_quarters',
    CURRENT_TIMESTAMP - INTERVAL '2 hours'
),
(
    '88888888-8888-8888-8888-888888888888',
    '66666666-6666-6666-6666-666666666666',
    '22222222-2222-2222-2222-222222222222',
    'half',
    CURRENT_TIMESTAMP - INTERVAL '3 hours'
);

-- ============================================
-- GRANT PRIVILEGES TO APPLICATION USER
-- ============================================

-- Create application user (run this as superuser before or after table creation)
-- Note: You need to create the user first if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'waste_app') THEN
        CREATE USER waste_app WITH PASSWORD 'YourSecurePassword123';
    END IF;
END
$$;

-- Grant privileges
GRANT CONNECT ON DATABASE waste_db TO waste_app;
GRANT USAGE ON SCHEMA public TO waste_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO waste_app;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO waste_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO waste_app;

-- ============================================
-- DATABASE COMMENTS FOR DOCUMENTATION
-- ============================================

COMMENT ON DATABASE waste_db IS 'Waste Management System - Production Database';
COMMENT ON EXTENSION postgis IS 'PostGIS spatial and geographic objects';
COMMENT ON EXTENSION "uuid-ossp" IS 'UUID generation functions';

COMMENT ON TABLE users IS 'System users: customers, drivers, and administrators';
COMMENT ON TABLE bins IS 'Waste containers registered by users';
COMMENT ON TABLE waste_reports IS 'Historical waste level reports from users';
COMMENT ON TABLE trucks IS 'Collection vehicles in the fleet';
COMMENT ON TABLE driver_profiles IS 'Extended information for driver users';
COMMENT ON TABLE location_updates IS 'GPS location history from driver devices';
COMMENT ON TABLE collection_routes IS 'Optimized collection routes for drivers';
COMMENT ON TABLE route_bins IS 'Junction table linking routes to bins with collection order';
COMMENT ON TABLE notifications IS 'Push notification delivery history';
COMMENT ON TABLE audit_log IS 'System audit trail for important changes';

-- ============================================
-- DATABASE MAINTENANCE TASKS (Optional)
-- ============================================

-- Create a function to clean up old location updates
CREATE OR REPLACE FUNCTION cleanup_old_location_updates(
    retention_days INTEGER DEFAULT 30
)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM location_updates 
    WHERE recorded_at < CURRENT_TIMESTAMP - (retention_days || ' days')::INTERVAL;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create a function to archive completed routes
CREATE OR REPLACE FUNCTION archive_old_routes(
    archive_months INTEGER DEFAULT 6
)
RETURNS INTEGER AS $$
DECLARE
    archived_count INTEGER;
BEGIN
    -- In future update, we would move to an archive table
    -- For now,we'll just mark as archived in metadata
    UPDATE collection_routes 
    SET metadata = jsonb_set(
        COALESCE(metadata, '{}'),
        '{archived_at}',
        to_jsonb(CURRENT_TIMESTAMP)
    )
    WHERE status = 'completed'
        AND completed_at < CURRENT_TIMESTAMP - (archive_months || ' months')::INTERVAL
        AND NOT metadata ? 'archived_at';
    
    GET DIAGNOSTICS archived_count = ROW_COUNT;
    RETURN archived_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FINAL SETUP COMPLETE
-- ============================================

-- Test the spatial function
SELECT * FROM find_bins_near_point(40.7128, -74.0060, 500);

-- Check the views
SELECT * FROM bins_urgent_collection;
SELECT * FROM active_drivers_status;

-- Verify UUID generation
SELECT uuid_generate_v4() AS new_uuid;

-- Show all tables
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;