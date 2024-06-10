CREATE DATABASE Team10;

use Team10;

CREATE TABLE Building
(
BNum INT IDENTITY NOT NULL PRIMARY KEY,
BName VARCHAR(255) NOT NULL
);

CREATE TABLE Apartment
(
ApartNo VARCHAR(4) NOT NULL PRIMARY KEY,
BNum INT NOT NULL REFERENCES Building(BNum),
NoOfTenants INT
);
 
CREATE TABLE Parking
(
ParkingLotID VARCHAR(6) NOT NULL PRIMARY KEY,
-- two wheeler or four wheeler
TypeOfParking BIT NOT NULL,
ApartNo VARCHAR(4) NOT NULL REFERENCES Apartment(ApartNo)
)
 
CREATE TABLE Contractor
(
CID VARCHAR(60) NOT NULL PRIMARY KEY,
Duration DATE
);
 
CREATE TABLE Service
(
SrID VARCHAR(20) NOT NULL PRIMARY KEY,
SrName VARCHAR(40) NOT NULL,
Cost MONEY NOT NULL,
CID VARCHAR(60) NOT NULL REFERENCES Contractor(CID)
);
 
CREATE TABLE MonthlyBill
(
BillReceiptNo INT IDENTITY NOT NULL PRIMARY KEY,
BillDate DATE NOT NULL,
ApartNo VARCHAR(4) NOT NULL REFERENCES Apartment(ApartNo),
SrID VARCHAR(20) NOT NULL REFERENCES Service(SrID)
);

CREATE TABLE Person
(
PID INT IDENTITY NOT NULL PRIMARY KEY,
SSN VARCHAR(255) NOT NULL UNIQUE,
PName VARCHAR(255) NOT NULL,
PhNumber VARCHAR(12),
ApartNo VARCHAR(4) NOT NULL REFERENCES Apartment(ApartNo)
);
 
CREATE TABLE Events
(
EID VARCHAR(4) NOT NULL PRIMARY KEY,
EName VARCHAR(40) NOT NULL,
Location VARCHAR(60) NOT NULL,
EventDate DATE NOT NULL,
EventTime TIME NOT NULL,
OrganizedBy INT NOT NULL REFERENCES Person(PID)
);
 
CREATE TABLE EventAttendees
(
PID INT NOT NULL REFERENCES Person(PID),
EID VARCHAR(4) NOT NULL REFERENCES Events(EID),
CONSTRAINT PKPersonEvent PRIMARY KEY CLUSTERED
	(PID, EID)
);
 
CREATE TABLE Guest
(
GID INT IDENTITY NOT NULL PRIMARY KEY,
PID INT NOT NULL REFERENCES Person(PID),
VisitedTime DATETIME
);
 
CREATE TABLE Staff
(
SID INT IDENTITY NOT NULL PRIMARY KEY,
Designation VARCHAR(40) NOT NULL,
StaffName VARCHAR(255) NOT NULL,
BNum INT NOT NULL REFERENCES Building(BNum)
);
 
CREATE TABLE Activity
(
ActivityID VARCHAR(20) NOT NULL PRIMARY KEY,
ActivityName VARCHAR(60) NOT NULL
);
 
CREATE TABLE RecreationalCenter
(
RoomNum VARCHAR(4) NOT NULL PRIMARY KEY,
ScheduleStartTime TIME NOT NULL,
ScheduleEndTime TIME NOT NULL,
Occupancy INT NOT NULL,
ActivityID VARCHAR(20) NOT NULL REFERENCES Activity(ActivityID),
BNum INT NOT NULL REFERENCES Building(BNum)
);
 
-- ENCRYPTION FOR SSN COLUMN
CREATE MASTER KEY
ENCRYPTION BY PASSWORD = 'Team10!@1132';
 
CREATE CERTIFICATE SSNCertificate
WITH SUBJECT = 'Team10 SSN Certificate',
EXPIRY_DATE = '2043-12-04';
 
CREATE SYMMETRIC KEY SSNSymmetricKey
WITH ALGORITHM = AES_128
ENCRYPTION BY CERTIFICATE SSNCertificate;
 
-- STORED PROCEDURE TO STORE PERSON DETAILS
CREATE PROCEDURE InsertPersonDetails
	@OriginalSSN VARCHAR(11),
    @PName VARCHAR(255),
    @PhNumber VARCHAR(12),
    @ApartNo VARCHAR(4)
AS
BEGIN
	DECLARE @EncryptedSSN VARBINARY(255);
 
	-- ENCRYPTING THE SSN VALUE
	OPEN SYMMETRIC KEY SSNSymmetricKey
	DECRYPTION BY CERTIFICATE SSNCertificate;
	
	SET @EncryptedSSN = EncryptByKey(Key_GUID(N'SSNSymmetricKey'), @OriginalSSN);
	
	CLOSE SYMMETRIC KEY SSNSymmetricKey;
 
	INSERT INTO Person(SSN, PName, PhNumber, ApartNo)
	VALUES(@EncryptedSSN, @PName, @PhNumber, @ApartNo);
END;
 

-- TABLE LEVEL CONSTRAINT FOR MONTHLY BILL
CREATE FUNCTION monthlyBill_check(@SrID VARCHAR(20))
RETURNS INT
AS
BEGIN
	DECLARE @IsServiceValid INT = 0;
	DECLARE @ContractorDuration DATE;
 
	SELECT @ContractorDuration = c.Duration
	FROM Service s
	JOIN Contractor c
	ON s.CID = c.CID
	WHERE s.SrID = @SrID;
 
	SELECT @IsServiceValid = CASE
		WHEN @ContractorDuration > GETDATE() THEN 1
		ELSE 0
		END;
	RETURN @IsServiceValid;
END;
ALTER TABLE MonthlyBill
ADD CONSTRAINT SrDurationRule CHECK(dbo.monthlyBill_check(SrID) = 1);
 
-- TABLE LEVEL CONSTRAINT FOR PERSON - Phone Number
CREATE FUNCTION IsValidPhoneNumber(@phNumber VARCHAR(12))
RETURNS BIT
AS
BEGIN
	RETURN CASE
		WHEN @phNumber LIKE '[1-9][0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]' THEN 1
		ELSE 0
	END;
END;
ALTER TABLE Person
ADD CONSTRAINT PhoneNumberRule CHECK(dbo.IsValidPhoneNumber(PhNumber) = 1);
 
 
-- COMPUTED COLUMN FOR APARTMENT
CREATE FUNCTION totalCostForApart(@ApartNo VARCHAR(4))
RETURNS MONEY
AS
BEGIN
	DECLARE @TotalCost MONEY = (SELECT SUM(s.Cost)
	FROM MonthlyBill mb
	JOIN Service s
	ON s.SrID = mb.SrID
	WHERE ApartNo = @ApartNo);
	SET @TotalCost = ISNULL(@TotalCost, 0);
	RETURN @TotalCost;
END;
ALTER TABLE Apartment
ADD ServiceTotal AS (dbo.totalCostForApart(ApartNo));

-- COMPUTED COLUMN FOR MONTHLY BILL
CREATE FUNCTION totalAmountMB(@SrID VARCHAR(20))
RETURNS MONEY
AS
BEGIN
	DECLARE @cost MONEY = (SELECT s.cost FROM Service s WHERE s.SrID = @SrID)
	RETURN @cost
END;
ALTER TABLE MonthlyBill
ADD TotalAmt AS (dbo.totalAmountMB(SrID));


SELECT * FROM Apartment a;
 
-- VIEW TO GET THE MONTHLY BILL DETAILS
CREATE VIEW MonthlyBillDetails AS
SELECT mb.BillReceiptNo,
mb.BillDate,
s.Cost,
a.ApartNo,
a.ServiceTotal AS TotalSoFar,
s.SrID,
s.SrName,
s.Cost,
c.CID,
c.Duration
FROM MonthlyBill mb
JOIN Apartment a
ON A.ApartNo = MB.ApartNo
JOIN Service s
ON s.SrID = mb.SrID
JOIN Contractor c
ON c.CID = s.CID;
SELECT * FROM MonthlyBillDetails;
 
-- VIEW TO SEE WHICH SERVICES HAVE THE HIGHEST SPENDING
CREATE VIEW HighestSpending AS
SELECT mb.SrID,
s.SrName,
s.CID,
SUM(mb.TotalAmt) AS ServiceTotalAmount,
COUNT(s.SrID) AS ServiceTotalAvailed,
RANK() OVER (ORDER BY SUM(mb.TotalAmt) DESC) AS RankedServiceTotal
FROM MonthlyBill mb
JOIN Apartment a
ON A.ApartNo = MB.ApartNo
JOIN Service s
ON s.SrID = mb.SrID
GROUP BY mb.SrID, s.SrName, s.CID;
SELECT * FROM HighestSpending;
 
-- VIEW TO SEE SERVICES RANKED BASED ON HOW FREQUENTYLY IT WAS AVAILED
CREATE VIEW ServiceFrequency AS
SELECT mb.SrID,
s.SrName,
s.CID,
COUNT(mb.SrID) AS ServiceAvailedCount,
RANK() OVER (ORDER BY COUNT(mb.SrID) DESC) AS RankedServiceFrequency
FROM MonthlyBill mb
JOIN Service s
ON s.SrID = mb.SrID
GROUP BY mb.SrID, s.SrName, s.CID;
SELECT * FROM ServiceFrequency;

-- VIEW TO SEE EVENT AND PERSON DETAILS
CREATE VIEW EventAttendance AS
WITH Temp AS(
SELECT p.PID,
p.PName AS AttendeeName,
a.ApartNo AS ApartmentNo,
e.EName AS EventName,
e.EventDate,
e.Location,
e.OrganizedBy
FROM EventAttendees ea
JOIN Person p 
ON ea.PID = p.PID
JOIN Events e
ON e.EID = ea.EID
JOIN Apartment a
ON p.ApartNo = a.ApartNo
)
SELECT t.PID,
t.AttendeeName,
t.ApartmentNo,
t.EventName,
t.EventDate,
t.Location, 
p.PName AS Organizer 
FROM Temp t
JOIN Person p
ON t.OrganizedBy = p.PID;
SELECT * FROM EventAttendance;


-- INSERTING DATA INTO PERSON TABLE
EXEC InsertPersonDetails @OriginalSSN = '145-47-6767', @PName = 'John Doe', @PhNumber = '344-456-4355', @ApartNo = 'A101';
EXEC InsertPersonDetails @OriginalSSN = '653-78-3535', @PName = 'Rachel Green', @PhNumber = '654-856-3465', @ApartNo = 'B102';
EXEC InsertPersonDetails @OriginalSSN = '132-96-4566', @PName = 'Michael Scott', @PhNumber = '867-756-2454', @ApartNo = 'B103';
EXEC InsertPersonDetails @OriginalSSN = '567-95-8676', @PName = 'Selina Meyer', @PhNumber = '876-267-7655', @ApartNo = 'B107';
EXEC InsertPersonDetails @OriginalSSN = '274-78-8865', @PName = 'Leslie Knope', @PhNumber = '454-345-5344', @ApartNo = 'A109';
EXEC InsertPersonDetails @OriginalSSN = '233-45-5653', @PName = 'Samantha Jones', @PhNumber = '765-764-6444', @ApartNo = 'A108';
EXEC InsertPersonDetails @OriginalSSN = '987-87-8365', @PName = 'Harvey Specter', @PhNumber = '233-866-5444', @ApartNo = 'A105';
EXEC InsertPersonDetails @OriginalSSN = '125-56-9933', @PName = 'Cookie Lyon', @PhNumber = '344-888-7456', @ApartNo = 'A103';
EXEC InsertPersonDetails @OriginalSSN = '887-67-8612', @PName = 'Barney Stinson', @PhNumber = '412-656-7566', @ApartNo = 'A102';
EXEC InsertPersonDetails @OriginalSSN = '967-67-9088', @PName = 'Anne Summers', @PhNumber = '412-455-3444', @ApartNo = 'A104';
EXEC InsertPersonDetails @OriginalSSN = '945-78-0987', @PName = 'Steven Fernandes', @PhNumber = '555-344-8977', @ApartNo = 'A106';

-- DATA INSERTION FOR BUILDING
INSERT INTO Building (BName)
VALUES
('33 Lancaster Ter, Brookline, MA 02446'),
('127 Hawes St, Boston, MA 02774'),
('123 Main Street, Los Angeles, CA 90001'),
('456 Elm Avenue, Tempe, AZ 85250'),
('234 Pine Lane, Boston, MA 02114'),
('345 Golden Gate Lane, San Diego, CA 92101'),
('890 Pacific Street, San Francisco, CA 94105'),
('678 Rocky Mountain Road, Denver, CO 80202'),
('456 Palm Street, Orlando, FL 32810'),
('789 Sunshine Avenue, Tampa, FL 33602')
('456 El Street, Troy, MI 48201')
('789 Jeff Avenue, Tampa, MI 48209');

-- DATA INSERTION FOR CONTRACTOR
INSERT INTO Contractor (CID, Duration)
VALUES
('Merry Maids', '2025-01-01'),
('LaundryConnect', '2025-02-01'),
('Amco Property Maintenance', '2025-03-01'),
('Servpro', '2025-04-01'),
('TaskRabbit', '2025-05-01'),
('Housekeep', '2025-06-01'),
('Molly Maid', '2025-07-01'),
('Handy', '2025-08-01'),
('Cleaners Inc', '2025-09-01'),
('Stanley Carpets', '2025-10-01');

-- DATA INSERTION FOR SERVICE
INSERT INTO Service (SrID, SrName, Cost, CID)
VALUES
('S01', 'Cleaning', 50.00, 'Merry Maids'),
('S02', 'Repair', 75.00, 'Amco Property Maintenance'),
('S03', 'Maintenance', 100.00, 'Amco Property Maintenance'),
('S04', 'Security', 150.00, 'Amco Property Maintenance'),
('S05', 'Gardening', 200.00, 'TaskRabbit'),
('S06', 'Laundry', 25.00, 'LaundryConnect'),
('S07', 'Catering', 300.00, 'Servpro'),
('S08', 'Transport', 350.00, 'Servpro'),
('S09', 'Internet', 45.00, 'Servpro'),
('S10', 'Gym', 400.00, 'Amco Property Maintenance');
DELETE FROM Service;

-- DATA INSERTION FOR APARTMENT
INSERT INTO Apartment (ApartNo, BNum, NoOfTenants) VALUES
('A251', 4, 3),
('A102', 1, 4),
('A103', 1, 2),
('A104', 1, 2),
('A105', 1, 2),
('A106', 1, 2),
('A107', 1, 4),
('A108', 1, 2),
('A109', 1, 2),
('B102', 1, 2),
('B103', 1, 3),
('B104', 1, 1),
('B105', 1, 3),
('B106', 1, 4),
('B107', 1, 2),
('B108', 1, 2),
('B109', 1, 2),
('C201', 1, 2),
('C202', 1, 4),
('C204', 1, 2);

-- DATA INSERTION FOR MONTHLYBILL
INSERT INTO MonthlyBill (BillDate, ApartNo, SrID) VALUES
('2023-01-01','A101', 'S01'),
('2023-02-01','A101', 'S02'),
('2023-03-01', 'A101', 'S03'),
('2023-04-01', 'A104', 'S04'),
('2023-05-01', 'A105', 'S05'),
('2023-06-01', 'A106', 'S06'),
('2023-07-01','A107', 'S07'),
('2023-08-01', 'A108', 'S08'),
('2023-09-01', 'A109', 'S09'),
('2023-10-01', 'A201', 'S10');
INSERT INTO MonthlyBill (BillDate, ApartNo, SrID) VALUES
('2023-01-01','A104', 'S01'),
('2023-01-01','A105', 'S01');
INSERT INTO MonthlyBill (BillDate, ApartNo, SrID) VALUES
('2023-02-01','A104', 'S01'),
('2023-02-01','A105', 'S01');


-- DATA INSERTION FOR EVENTS
INSERT INTO Events (EID, EName, Location, EventDate, EventTime, OrganizedBy)
VALUES
    ('E001', 'Art Exhibition', 'Art Gallery', '2023-04-15', '14:00:00', 4),
    ('E002', 'Tech Talk', 'Innovation Center', '2023-05-10', '16:30:00', 5),
    ('E003', 'Fitness Workshop', 'Health Club', '2023-06-05', '18:00:00', 6),
    ('E004', 'Book Launch', 'Bookstore', '2023-07-20', '19:15:00', 7),
    ('E005', 'Cooking Class', 'Culinary School', '2023-08-12', '15:30:00', 8),
    ('E006', 'Fashion Show', 'Fashion Mall', '2023-09-28', '20:00:00', 9),
    ('E007', 'Movie Night', 'Community Park', '2023-10-15', '19:45:00', 10),
    ('E008', 'Dance Competition', 'Dance Studio', '2023-11-08', '17:00:00', 4),
    ('E009', 'Science Fair', 'Science Museum', '2023-12-03', '10:30:00', 4),
    ('E010', 'Gaming Tournament', 'Gaming Lounge', '2024-01-18', '21:00:00', 4);

-- DATA INSERTION FOR EVENTATTENDEES
INSERT INTO EventAttendees (PID, EID)
VALUES
    (1, 'E001'),
    (2, 'E001'),
    (3, 'E002'),
    (4, 'E002'),
    (5, 'E003'),
    (1, 'E003'),
    (1, 'E004'),
    (2, 'E004'),
    (9, 'E005'),
    (10, 'E005');
    

-- DATA INSERTION FOR ACTIVITY
INSERT INTO Activity (ActivityID, ActivityName) VALUES ('YGCLMRG', 'Yoga Class');
INSERT INTO Activity (ActivityID, ActivityName) VALUES ('FITCMPEVG', 'Fitness Bootcamp');
INSERT INTO Activity (ActivityID, ActivityName) VALUES ('ARTEVG', 'Art Class');
INSERT INTO Activity (ActivityID, ActivityName) VALUES ('CKCLSAFT', 'Cooking Class');
INSERT INTO Activity (ActivityID, ActivityName) VALUES ('DNCESESEVG', 'Dance Session');
INSERT INTO Activity (ActivityID, ActivityName) VALUES ('MSCJMEVG', 'Music Jam');
INSERT INTO Activity (ActivityID, ActivityName) VALUES ('BKCLAFT', 'Book Club');
INSERT INTO Activity (ActivityID, ActivityName) VALUES ('GAMNIT', 'Gaming Night');
INSERT INTO Activity (ActivityID, ActivityName) VALUES ('MOVSCRNIT', 'Movie Screening');
INSERT INTO Activity (ActivityID, ActivityName) VALUES ('TECHDY', 'Tech Hackathon');

-- DATA INSERTION FOR RecreationalCenter
INSERT INTO RecreationalCenter (RoomNum, ScheduleStartTime, ScheduleEndTime, Occupancy, ActivityID, BNum)
VALUES
    ('R101', '08:00:00', '10:00:00', 30, 'YGCLMRG', 1),
    ('R102', '12:00:00', '14:00:00', 25, 'CKCLSAFT', 1),
    ('R103', '15:30:00', '17:30:00', 20, 'FITCMPEVG', 1),
    ('R104', '09:00:00', '17:00:00', 35, 'TECHDY', 1),
    ('R105', '16:00:00', '18:00:00', 28, 'ARTEVG', 1),
    ('R106', '17:00:00', '19:00:00', 22, 'DNCESESEVG', 1),
    ('R107', '21:30:00', '23:30:00', 22, 'GAMNIT', 1),
    ('R108', '20:30:00', '23:30:00', 18, 'MOVSCRNIT', 1),
    ('R109', '16:30:00', '18:30:00', 32, 'MSCJMEVG', 1),
    ('R110', '12:00:00', '13:00:00', 30, 'BKCLAFT', 1);

-- DATA INSERTION FOR GUEST
INSERT INTO Guest (PID, VisitedTime) VALUES
    (1, '2023-04-01 08:30:00'),
    (2, '2023-04-02 10:15:00'),
    (1, '2023-04-03 12:45:00'),
    (1, '2023-04-04 15:20:00'),
    (5, '2023-04-05 18:00:00'),
    (6, '2023-04-06 09:45:00'),
    (4, '2023-04-07 14:30:00'),
    (8, '2023-04-08 16:10:00'),
    (9, '2023-04-09 11:25:00'),
    (1, '2023-04-10 13:40:00'),
    (11, '2023-04-11 17:00:00');

-- DATA INSERTION FOR STAFF
INSERT INTO Staff (Designation, StaffName, BNum) VALUES
    ('Building Manager', 'John Doe', 1),
    ('Front Desk Clerk', 'Jane Smith', 1),
    ('Accountant', 'Mike Johnson', 1),
    ('IT Support', 'Emily Brown', 1),
    ('Event Coordinator', 'David Wilson', 1),
    ('Waitstaff', 'Sarah Miller', 1),
    ('Housekeeping Supervisor', 'Brian Davis', 1),
    ('Concierge', 'Amanda Taylor', 1),
    ('Groundskeeper', 'Christopher White', 1),
    ('Security Supervisor', 'Olivia Garcia', 1);

-- DATA INSERTION FOR PARKING
INSERT INTO Parking (ParkingLotID, TypeOfParking, ApartNo)
VALUES
('PL001', 0, 'A101'),
('PL002', 1, 'A101'),
('PL003', 0, 'A102'),
('PL004', 1, 'A103'),
('PL005', 0, 'A104'),
('PL006', 1, 'A105'),
('PL007', 0, 'A106'),
('PL008', 1, 'A107'),
('PL009', 0, 'A108'),
('PL010', 1, 'A109');


