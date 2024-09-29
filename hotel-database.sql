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
    number               INT     NOT NULL,
    children_zone_exists BOOLEAN NOT NULL DEFAULT FALSE
);

ALTER TABLE default_rooms
    ADD CONSTRAINT fk_rooms FOREIGN KEY (number) REFERENCES rooms (number);

CREATE TABLE IF NOT EXISTS president_rooms
(
    number            INT     NOT NULL,
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