CREATE TABLE IF NOT EXISTS clients
(
    passport     VARCHAR(10) PRIMARY KEY,
    name         VARCHAR(100) NOT NULL,
    phone_number VARCHAR(10)  NOT NULL
);

CREATE TABLE IF NOT EXISTS rooms
(
    number            INT PRIMARY KEY CHECK (number > 0),
    area              INT NOT NULL CHECK (area > 0),
    single_beds_count INT NOT NULL CHECK (single_beds_count >= 0),
    double_beds_count INT NOT NULL CHECK (double_beds_count >= 0)
);

CREATE TABLE IF NOT EXISTS default_rooms
(
    number               INT     NOT NULL PRIMARY KEY,
    children_zone_exists BOOLEAN NOT NULL DEFAULT FALSE
);

ALTER TABLE default_rooms
    ADD CONSTRAINT fk_rooms FOREIGN KEY (number) REFERENCES rooms (number);

CREATE TABLE IF NOT EXISTS president_rooms
(
    number            INT     NOT NULL PRIMARY KEY,
    suitable_for_vips BOOLEAN NOT NULL DEFAULT FALSE
);

ALTER TABLE president_rooms
    ADD CONSTRAINT fk_rooms FOREIGN KEY (number) REFERENCES rooms (number);

CREATE TABLE IF NOT EXISTS orders
(
    price           NUMERIC(10, 2)   NOT NULL CHECK (price >= 0),
    arrival_date    DATE             NOT NULL,
    departure_date  DATE             NOT NULL CHECK (departure_date > arrival_date),
    client_passport VARCHAR(10)      NOT NULL,
    room_number     INT              NOT NULL,
    order_id        BIGSERIAL UNIQUE NOT NULL,
    PRIMARY KEY (client_passport, room_number, arrival_date)
);

ALTER TABLE orders
    ADD CONSTRAINT fk_clients FOREIGN KEY (client_passport) REFERENCES clients (passport),
    ADD CONSTRAINT fk_rooms FOREIGN KEY (room_number) REFERENCES rooms (number);

CREATE TABLE IF NOT EXISTS workers
(
    passport VARCHAR(10) PRIMARY KEY,
    name     VARCHAR(100) NOT NULL,
    position VARCHAR(70)  NOT NULL,
    chief    VARCHAR(10) CHECK (chief != passport)
);

ALTER TABLE workers
    ADD CONSTRAINT fk_workers_chief FOREIGN KEY (chief) REFERENCES workers (passport);

CREATE TABLE IF NOT EXISTS room_responsible
(
    worker_passport VARCHAR(10) NOT NULL,
    room_number     INT         NOT NULL,
    PRIMARY KEY (worker_passport, room_number)
);

ALTER TABLE room_responsible
    ADD CONSTRAINT fk_workers FOREIGN KEY (worker_passport) REFERENCES workers (passport),
    ADD CONSTRAINT fk_rooms FOREIGN KEY (room_number) REFERENCES rooms (number);

-- validate default_rooms insert/update
CREATE OR REPLACE FUNCTION validate_table_update_for_default_rooms()
    RETURNS TRIGGER AS
$$
BEGIN
    IF EXISTS(SELECT 1 FROM president_rooms WHERE number = NEW.number) THEN
        RAISE EXCEPTION 'Room % already exists in president_rooms', NEW.number;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_default_rooms_validate_table_update
    BEFORE INSERT OR UPDATE
    ON default_rooms
    FOR EACH ROW
EXECUTE FUNCTION validate_table_update_for_default_rooms();

-- validate president_rooms insert/update
CREATE OR REPLACE FUNCTION validate_table_update_for_president_rooms()
    RETURNS TRIGGER AS
$$
BEGIN
    IF EXISTS(SELECT 1 FROM default_rooms WHERE number = NEW.number) THEN
        RAISE EXCEPTION 'Room % already exists in default_rooms', NEW.number;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_president_rooms_validate_table_update
    BEFORE INSERT OR UPDATE
    ON president_rooms
    FOR EACH ROW
EXECUTE FUNCTION validate_table_update_for_president_rooms();

-- validate order insert
CREATE OR REPLACE FUNCTION validate_table_create_for_orders()
    RETURNS TRIGGER AS
$$
BEGIN
    IF EXISTS(
            SELECT 1
            FROM orders
            WHERE room_number = NEW.room_number
              AND (departure_date > NEW.arrival_date AND NEW.departure_date > arrival_date)) THEN
        RAISE EXCEPTION 'Room % already ordered in that period', NEW.room_number;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_orders_validate_table_insert
    BEFORE INSERT
    ON orders
    FOR EACH ROW
EXECUTE FUNCTION validate_table_create_for_orders();


-- validate order update
CREATE OR REPLACE FUNCTION validate_table_update_for_orders()
    RETURNS TRIGGER AS
$$
BEGIN
    IF EXISTS(
            SELECT 1
            FROM orders
            WHERE room_number = NEW.room_number
              AND (departure_date > NEW.arrival_date AND NEW.departure_date > arrival_date)
              AND (order_id != NEW.order_id)
        ) THEN
        RAISE EXCEPTION 'Room % already ordered in that period', NEW.room_number;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_orders_validate_table_update
    BEFORE UPDATE
    ON orders
    FOR EACH ROW
EXECUTE FUNCTION validate_table_update_for_orders();

INSERT INTO clients (passport, name, phone_number) VALUES
('P123456789', 'Alice Smith', '1234567890'),
('P987654321', 'Bob Johnson', '0987654321'),
('P111222333', 'Charlie Brown', '1112223333'),
('P444555666', 'David Lee', '4445556660'),
('P222333444', 'Sophia Brown', '2223334444'),
('P555666777', 'James Williams', '5556667777'),
('P333444555', 'Emily Davis', '3334445555'),
('P666777888', 'Michael Wilson', '6667778888');

INSERT INTO rooms (number, area, single_beds_count, double_beds_count) VALUES
(101, 25, 1, 1),
(102, 20, 2, 0),
(201, 30, 0, 1),
(301, 35, 1, 1),
(202, 40, 2, 1),
(203, 25, 1, 1),
(204, 28, 0, 2),
(302, 50, 2, 2),
(303, 45, 1, 1),
(304, 60, 0, 2);

INSERT INTO default_rooms (number, children_zone_exists) VALUES
(101, TRUE),
(102, FALSE),
(203, TRUE),
(204, FALSE),
(303, FALSE);

INSERT INTO president_rooms (number, suitable_for_vips) VALUES
(201, TRUE),
(202, TRUE),
(301, FALSE),
(304, TRUE);

INSERT INTO orders (price, arrival_date, departure_date, client_passport, room_number) VALUES
(150.00, '2023-11-01', '2023-11-05', 'P123456789', 101),
(200.00, '2023-11-10', '2023-11-15', 'P987654321', 201),
(180.00, '2023-12-01', '2023-12-05', 'P111222333', 102),
(120.00, '2023-11-02', '2023-11-06', 'P444555666', 203),
(300.00, '2023-11-11', '2023-11-16', 'P222333444', 202),
(250.00, '2023-11-20', '2023-11-25', 'P555666777', 303),
(175.00, '2023-12-10', '2023-12-15', 'P333444555', 204),
(400.00, '2023-12-20', '2023-12-30', 'P666777888', 304),
(550.00, '2024-01-01', '2024-12-03', 'P987654321', 201),
(450.00, '2024-11-11', '2024-11-26', 'P222333444', 303);

INSERT INTO workers (passport, name, position, chief) VALUES
('W123456789', 'Emma Stone', 'Manager', NULL),
('W987654321', 'Liam White', 'Receptionist', 'W123456789'),
('W111222333', 'Olivia Green', 'Cleaner', 'W123456789'),
('W444555666', 'George Brown', 'Receptionist', 'W123456789'),
('W222333444', 'Jessica Taylor', 'Security', 'W123456789'),
('W555666777', 'Lucas Miller', 'Cleaner', 'W987654321'),
('W333444555', 'Ella Moore', 'Housekeeping', 'W987654321'),
('W666777888', 'Ethan Thomas', 'Maintenance', 'W987654321');

INSERT INTO room_responsible (worker_passport, room_number) VALUES
('W987654321', 101),
('W987654321', 102),
('W111222333', 201),
('W444555666', 203),
('W222333444', 202),
('W555666777', 303),
('W333444555', 204),
('W666777888', 304),
('W987654321', 301),
('W111222333', 302);
