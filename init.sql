USE master

-- Tworzenie pustej bazy danych
IF DB_ID('Project') IS NOT NULL
    DROP DATABASE Project

CREATE DATABASE Project

USE Project

-- Lista graczy
CREATE TABLE Players(
	Player_ID INT PRIMARY KEY IDENTITY(1,1),
	Pass NVARCHAR(64) NOT NULL,
	Email NVARCHAR(64) UNIQUE NOT NULL
)

--Lista gildii
CREATE TABLE Guilds(
	Guild_ID INT PRIMARY KEY IDENTITY(1,1),
	Guild_owner INT NOT NULL,
	Name NVARCHAR(32) UNIQUE NOT NULL,
	Members INT NOT NULL DEFAULT 0,
)

--Lista lokacji
CREATE TABLE Locations(
	Location_ID INT PRIMARY KEY IDENTITY(1,1),
	Name NVARCHAR(32) UNIQUE NOT NULL,
	Location_lvl INT NOT NULL
)

--Lista połączeń między lokacjami
CREATE TABLE LocationsConnetions(
	Source_Location_ID INT NOT NULL FOREIGN KEY REFERENCES Locations(Location_ID),
	Destination_Location_ID INT NOT NULL FOREIGN KEY REFERENCES Locations(Location_ID),
	PRIMARY KEY (Source_Location_ID, Destination_Location_ID)
)

-- Lista postaci
CREATE TABLE Characters(
	Character_ID INT PRIMARY KEY IDENTITY(1,1),
	Player_ID INT NOT NULL FOREIGN KEY REFERENCES Players(Player_ID),
	Guild_ID INT FOREIGN KEY REFERENCES Guilds(Guild_ID),
	Location_ID INT NOT NULL FOREIGN KEY REFERENCES Locations(Location_ID) DEFAULT 1,
	Nick NVARCHAR(32) UNIQUE NOT NULL,
	Max_hp INT NOT NULL DEFAULT 100,
	Hp INT NOT NULL DEFAULT 100,
	Lvl INT NOT NULL DEFAULT 1,
	Character_exp INT NOT NULL DEFAULT 0,
	Gold INT NOT NULL DEFAULT 50
)

ALTER TABLE Guilds ADD CONSTRAINT fk_owner FOREIGN KEY(Guild_owner) REFERENCES Characters(Character_ID)

--Lista przedmiotów
CREATE TABLE Items (
	Item_ID INT PRIMARY KEY IDENTITY(1,1),
	Name NVARCHAR(32) UNIQUE NOT NULL,
	Attack INT,
	Defence INT,
	Hp INT
)

--Ekwipunek gracza
CREATE TABLE Inventory (
	Character_ID INT NOT NULL FOREIGN KEY REFERENCES Characters(Character_ID),
	Item_ID INT NOT NULL FOREIGN KEY REFERENCES Items(Item_ID),
	Item_lvl INT,
	Item_amount INT NOT NULL,
	PRIMARY KEY (Character_ID, Item_ID, Item_lvl)
)

--Lista Zbanowanych
CREATE TABLE Banned (
	Player_ID INT NOT NULL FOREIGN KEY REFERENCES Players(Player_ID) ON DELETE CASCADE,
	Start DATE NOT NULL,
	Finish DATE NOT NULL,
	Reason NVARCHAR(256) NOT NULL
	PRIMARY KEY (Player_ID, Start)
)

--Lista wszystkich NPC
CREATE TABLE NPCs (
	NPC_ID INT PRIMARY KEY IDENTITY(1,1),
	Location_ID INT NOT NULL FOREIGN KEY REFERENCES Locations(Location_ID) ON DELETE CASCADE,
	Name NVARCHAR(32) UNIQUE NOT NULL
)

--Lista Przeciwników
CREATE TABLE Enemies (
	Enemy_ID INT PRIMARY KEY FOREIGN KEY REFERENCES NPCs(NPC_ID) ON DELETE CASCADE,
	Hp INT NOT NULL,
	Defence INT NOT NULL,
	Attack INT NOT NULL,
	Kill_exp INT NOT NULL,
)

--Lista przedmiotów które wypadają
CREATE TABLE EnemyDrops (
	Enemy_ID INT NOT NULL FOREIGN KEY REFERENCES Enemies(Enemy_ID) ON DELETE CASCADE,
	Item_ID INT NOT NULL FOREIGN KEY REFERENCES Items(Item_ID) ON DELETE CASCADE,
	Drop_chance FLOAT NOT NULL
	PRIMARY KEY (Enemy_ID, Item_ID)
)

--Lista Przyjaznych NPC
CREATE TABLE Friends (
	Friend_ID INT NOT NULL PRIMARY KEY FOREIGN KEY REFERENCES NPCs(NPC_ID) ON DELETE CASCADE,
	Store_ID INT UNIQUE NOT NULL
)

--Lista sklepów
CREATE TABLE Stores (
	Store_ID INT NOT NULL FOREIGN KEY REFERENCES Friends(Store_ID) ON DELETE CASCADE,
	Item_ID INT NOT NULL FOREIGN KEY REFERENCES Items(Item_ID) ON DELETE CASCADE,
	Item_lvl INT NOT NULL,
	Unit_cost INT NOT NULL
	PRIMARY KEY (Store_ID, Item_ID, Item_lvl)
)

--Dom aukcyjny
CREATE TABLE AuctionHouse (
	Offer_ID INT NOT NULL PRIMARY KEY IDENTITY(1,1),
	Seller_ID INT NOT NULL FOREIGN KEY REFERENCES Characters(Character_ID),
	Item_ID INT NOT NULL FOREIGN KEY REFERENCES Items(Item_ID),
	Item_lvl INT,
	Starting_Price INT NOT NULL,
	Beggin_date DATE NOT NULL,
	End_date DATE NOT NULL
)

--oferty w domu aukcyjnym
CREATE TABLE AuctionHouseBids (
	Offer_ID INT NOT NULL FOREIGN KEY REFERENCES AuctionHouse(Offer_ID),
	Bidder_ID INT NOT NULL FOREIGN KEY REFERENCES Characters(Character_ID),
	Bid_amount INT NOT NULL
	PRIMARY KEY (Offer_ID,Bidder_ID)
)

--Lista zadań
CREATE TABLE Quests(
	Quest_ID INT PRIMARY KEY IDENTITY(1,1),
	Min_lvl INT NOT NULL,
	Quest_name NVARCHAR(32) UNIQUE NOT NULL,
	Quest_desc NVARCHAR(256) UNIQUE NOT NULL,
	Quest_Giver INT NOT NULL FOREIGN KEY REFERENCES NPCs(NPC_ID) ON DELETE CASCADE,
	--warunki wygranej
	Npc_ID INT FOREIGN KEY REFERENCES NPCs(NPC_ID),
	Item_ID INT FOREIGN KEY REFERENCES Items(Item_ID) ON DELETE CASCADE,
	Item_lvl INT,
	Item_amount INT
)

--lista aktywnych questow
CREATE TABLE QuestsTracker(
	Character_ID INT NOT NULL REFERENCES Characters(Character_ID) ON DELETE CASCADE,
	Quest_ID INT NOT NULL REFERENCES Quests(Quest_ID) ON DELETE CASCADE,
	Quest_Status INT NOT NULL
	PRIMARY KEY (Quest_ID,Character_ID)
)

--Lista nagród
CREATE TABLE Rewards(
	Quest_ID INT NOT NULL REFERENCES Quests(Quest_ID) ON DELETE CASCADE,
	Item_ID INT NOT NULL REFERENCES Items(Item_ID),
	Item_lvl INT,
	Amount INT NOT NULL
	PRIMARY KEY(Quest_ID, Item_ID, Item_lvl)
)

------procedury, funkcje i widoki

----widoki

GO
--Widok pokazujacy aktualnie zbanowanych graczy
CREATE VIEW CurrentlyBanned AS
	SELECT B.Player_ID, B.Finish, B.Reason
	FROM Banned B
	WHERE GETDATE() BETWEEN B.Start AND B.Finish
GO

----funkcje

--Funkcja do logowania
CREATE FUNCTION TryToLogin (@Email NVARCHAR(64), @Password NVARCHAR(64))
RETURNS INT
AS BEGIN
	DECLARE @Res INT
	IF (EXISTS(SELECT * FROM Players P WHERE Email=@Email AND Pass=@Password) AND NOT EXISTS(SELECT * FROM Players P JOIN Banned B ON P.Player_ID = B.Player_ID WHERE GETDATE() BETWEEN B.Start AND B.Finish AND P.Email=@Email))
		SET @Res = (SELECT Player_ID FROM Players WHERE Email=@Email)
	ELSE
		SET @Res = -1
	RETURN @Res
END
GO

--funkcja wypisujaca przedmioty nalezace do danej postaci
CREATE FUNCTION CharacterInventory (@Character_ID INT)
RETURNS TABLE
AS
RETURN
    SELECT It.Name, It.Item_ID, Inv.Item_lvl, Inv.Item_amount 
    FROM Inventory Inv
	LEFT JOIN Items It ON Inv.Item_ID=It.Item_ID
	WHERE Inv.Character_ID=@Character_ID
GO

--funkcja wypisujaca postacie utworzone przez danego gracza
CREATE FUNCTION PlayerCharacters (@Player_ID INT)
RETURNS TABLE
AS
RETURN
    SELECT C.Character_ID, Nick, G.Name GuildName, L.Location_ID CurrentLocation, C.Lvl, C.Gold
    FROM Characters C
	LEFT JOIN Guilds G ON C.Guild_ID=G.Guild_ID
	LEFT JOIN Locations L ON C.Location_ID=L.Location_ID
	WHERE C.Player_ID=@Player_ID
GO

--funkcja wypisująca postacie nalezace do danej gildii
CREATE FUNCTION CharactersInGuild (@Guild_ID INT)
RETURNS TABLE
AS
RETURN
    SELECT Nick, Lvl, Gold
    FROM Characters C
	WHERE C.Guild_ID=@Guild_ID
GO


--funkcja wypisująca wszystkich przeciwnikow w danej lokacji
CREATE FUNCTION EnemiesInLocation (@Location_ID INT)
RETURNS TABLE
AS
RETURN
    SELECT E.Enemy_ID, N.Name, E.Kill_exp
    FROM Enemies E 
	LEFT JOIN NPCs N ON E.Enemy_ID=N.NPC_ID
	WHERE N.Location_ID=@Location_ID
GO


--funkcja wypisująca wszystkich przyjaznych NPC w danej lokacji
CREATE FUNCTION FriendsInLocation (@Location_ID INT)
RETURNS TABLE
AS
RETURN
    SELECT F.Friend_ID, N.Name, F.Store_ID
    FROM Friends F
	LEFT JOIN NPCs N ON F.Friend_ID=N.NPC_ID
	WHERE N.Location_ID=@Location_ID
GO

--funkcja wypisująca wszystkich lokacje do ktorych moze przejsc postac
CREATE FUNCTION AccessibleLocations (@Character_ID INT)
RETURNS TABLE
AS
RETURN
    SELECT L.Location_ID, L.Name, L.Location_lvl
    FROM (
		SELECT *
		FROM Characters
		WHERE Character_ID=@Character_ID
	) C
	LEFT JOIN LocationsConnetions Lc ON C.Location_ID=Lc.Source_Location_ID
	LEFT JOIN Locations L ON Lc.Destination_Location_ID=L.Location_ID
GO

--funkcja wypisująca wszystkie questy dawane przez danego przyjaznego NPC
CREATE FUNCTION NPCsQuests (@Friend_ID INT)
RETURNS TABLE
AS
RETURN
    SELECT Q.Quest_ID, Q.Quest_name, Q.Min_lvl
    FROM Quests Q
	WHERE Q.Quest_Giver=@Friend_ID

GO

--funkcja wypisująca wszystkie przedmioty w danym sklepie
CREATE FUNCTION ItemsInStore (@Store_ID INT)
RETURNS TABLE
AS
RETURN
    SELECT S.Item_ID, I.Name, S.Item_lvl, S.Unit_cost
    FROM Stores S
	LEFT JOIN Items I ON S.Item_ID=I.Item_ID
	WHERE S.Store_ID=@Store_ID

GO

--funkcja wypisująca wszystkie nagrody przyznane za dany quest
CREATE FUNCTION RewardsForQuest (@Quest_ID INT)
RETURNS TABLE
AS
RETURN
    SELECT R.Item_ID, I.Name, R.Item_lvl, R.Amount
    FROM Rewards R
	LEFT JOIN Items I ON R.Item_ID=I.Item_ID
	WHERE R.Quest_ID=@Quest_ID

GO

----procedury

--Procedura do rejestracji
CREATE PROCEDURE Register (@Email NVARCHAR(64), @Password NVARCHAR(64))
AS
	IF @Email NOT IN (SELECT Email FROM Players)
		INSERT INTO Players VALUES (@Password, @Email)

GO

--Procedura do dodawania postaci
CREATE PROCEDURE CreateCharacter(@PlayerID INT, @Nick NVARCHAR(32))
AS
	IF @Nick NOT IN (SELECT Email FROM Players)
		INSERT INTO Characters(Player_ID, Nick) VALUES (@PlayerID, @Nick)

GO

CREATE PROCEDURE BanPlayer(@Nick NVARCHAR(32), @Duration INT, @Reason NVARCHAR(256))
AS
	DECLARE @PlayerID INT
	SET @PlayerID = (SELECT Player_ID FROM Characters WHERE Nick=@Nick)
	DECLARE @EndDate DATE
	SET @EndDate = DATEADD(DAY, @Duration, GETDATE())
	INSERT INTO Banned VALUES (@PlayerID, GETDATE(), @EndDate, @Reason)

GO

CREATE PROCEDURE AttemptToMove(@Character_ID INT, @Destination_ID INT)
AS
BEGIN
  DECLARE @Res INT
	IF (EXISTS(
		SELECT *
		FROM LocationsConnetions Lc
		JOIN Locations L ON Lc.Destination_Location_ID=L.Location_ID
		WHERE Lc.Source_Location_ID = (
			SELECT Location_ID
			FROM Characters
			WHERE Character_ID=@Character_ID)
		AND
			Lc.Destination_Location_ID = @Destination_ID
		AND
			L.Location_lvl <= (
			SELECT Lvl
			FROM Characters
			WHERE Character_ID=@Character_ID)
	))
	BEGIN
		SET @Res = 1
		UPDATE Characters
		SET Location_ID=@Destination_ID
		WHERE Character_ID=@Character_ID
	END
	ELSE SET @Res = 0
	RETURN @Res
END
GO

CREATE PROCEDURE AttemptToBuy(@Character_ID INT, @Store_ID INT, @Item_ID INT, @Item_lvl INT, @Amount INT)
AS
BEGIN
	DECLARE @Res INT
	IF (EXISTS(
	SELECT *
	FROM Stores S
	WHERE S.Store_ID=@Store_ID AND S.Item_ID=@Item_ID AND S.Item_lvl=@Item_lvl AND 
	S.Item_lvl<=(
		SELECT Lvl
		FROM Characters
		WHERE Character_ID=@Character_ID)
	AND S.Unit_cost<= @Amount*(
		SELECT Gold
		FROM Characters
		WHERE Character_ID=@Character_ID)
	))
	BEGIN
		SET @Res = 1

		UPDATE Characters
		SET Gold-=@Amount*(
			SELECT S.Unit_cost
			FROM Stores S
			WHERE S.Store_ID=@Store_ID AND S.Item_ID=@Item_ID AND S.Item_lvl=@Item_lvl
		)
		WHERE Character_ID=@Character_ID

		INSERT INTO Inventory
		VALUES (@Character_ID, @Item_ID, @Item_lvl,@Amount)

	END
	ELSE SET @Res = 0
	RETURN @Res
END
GO

CREATE PROCEDURE RemoveMember(@Character_ID INT, @Guild_ID INT)
AS
BEGIN
	IF(EXISTS(
		SELECT *
		FROM Guilds
		WHERE Guild_ID=@Guild_ID AND Guild_owner=@Character_ID
		))
	BEGIN
		DELETE FROM Guilds
		WHERE Guild_ID=@Guild_ID;
	END
	ELSE 
	BEGIN
		UPDATE Guilds
		SET Members-=1
		WHERE Guild_ID=@Guild_ID;

		UPDATE Characters
		SET Guild_ID=NULL
		WHERE Character_ID=@Character_ID AND Guild_ID=@Guild_ID;
	END
END
GO

CREATE PROCEDURE AddMember(@Character_ID INT, @Guild_ID INT)
AS
BEGIN
	IF(EXISTS(
		SELECT *
		FROM Characters
		WHERE Character_ID=@Character_ID AND Guild_ID IS NOT NULL
		))
	BEGIN
	DECLARE @CharactersGuild INT
	SET @CharactersGuild=(
		SELECT Guild_ID
		FROM Characters
		WHERE Character_ID=@Character_ID)

		EXEC RemoveMember @Character_ID=@Character_ID , @Guild_ID=@CharactersGuild
	END

	UPDATE Guilds
	SET Members+=1
	WHERE Guild_ID=@Guild_ID;

	UPDATE Characters
	SET Guild_ID=@Guild_ID
	WHERE Character_ID=@Character_ID;
END
GO


CREATE PROCEDURE Death(@Character_ID INT)
AS
BEGIN
	
	DECLARE @Max_hp INT
	SET @Max_hp=(
		SELECT Max_hp
		FROM Characters
		WHERE Character_ID=@Character_ID)

	UPDATE Characters
	SET HP=@Max_hp, Gold=0
	WHERE Character_ID=@Character_ID
	
END
GO

CREATE PROCEDURE Level_up(@Character_ID INT)
AS
BEGIN
	
		UPDATE Characters
		SET Lvl+=1, Max_hp+=10
		WHERE Character_ID=@Character_ID

		UPDATE Characters
		SET Hp=(
			SELECT Max_hp
			FROM Characters
			WHERE Character_ID=@Character_ID)
		WHERE Character_ID=@Character_ID
	
END
GO


CREATE PROCEDURE Gain_Exp(@Character_ID INT,@Exp_gain INT)
AS
BEGIN
	
	DECLARE @Max_hp INT
	SET @Max_hp=(
		SELECT Max_hp
		FROM Characters
		WHERE Character_ID=@Character_ID)

	UPDATE Characters
	SET Character_exp+=@Exp_gain
	WHERE Character_ID=@Character_ID

	WHILE(
		SELECT Character_exp
		FROM Characters
		WHERE Character_ID=@Character_ID)>=1000
	BEGIN
		UPDATE Characters
		SET Character_exp-=1000
		WHERE Character_ID=@Character_ID

		EXEC Level_up @Character_ID=@Character_ID

	END
	
END
GO

CREATE PROCEDURE AcceptQuest(@Character_ID INT,@Quest_ID INT)
AS
BEGIN
	INSERT INTO QuestsTracker VALUES
	(@Character_ID, @Quest_ID, 1)

END
GO

CREATE PROCEDURE ReturnQuest(@Character_ID INT,@Quest_ID INT)
AS
BEGIN
	UPDATE QuestsTracker
	SET Quest_Status=0
	WHERE Character_ID=@Character_ID AND Quest_ID=@Quest_ID

END
GO

CREATE PROCEDURE BidOnAuction(@Character_ID INT,@Offer_ID INT, @Gold INT)
AS
BEGIN
	DECLARE @Gold_Difrence INT
	SET @Gold_Difrence=@Gold
	SELECT @Gold_Difrence
	IF(EXISTS(
		SELECT *
		FROM AuctionHouseBids
		WHERE Offer_ID=@Offer_ID AND Bidder_ID=@Character_ID
	))
	BEGIN
		SET @Gold_Difrence-=(
			SELECT Bid_amount
			FROM AuctionHouseBids
			WHERE Offer_ID=@Offer_ID AND Bidder_ID=@Character_ID)

		UPDATE AuctionHouseBids
		SET Bid_amount=@Gold
		WHERE Offer_ID=@Offer_ID AND Bidder_ID=@Character_ID
	END
	ELSE BEGIN
		INSERT INTO AuctionHouseBids VALUES
		(@Offer_ID, @Character_ID, @Gold)
	END
	SELECT @Gold_Difrence

	UPDATE Characters
	SET Gold-=@Gold_Difrence
	WHERE Character_ID=@Character_ID

END
GO


--wyzwalacze

CREATE TRIGGER addItem ON Inventory
INSTEAD OF INSERT
AS BEGIN

	DECLARE @Character_ID INT;
    DECLARE @Item_ID INT;
    DECLARE @Item_lvl INT;
	DECLARE @Item_amount INT;
	DECLARE @Item_Hp INT;

	


    SELECT @Character_ID = Character_ID, @Item_ID = I.Item_ID, @Item_lvl = Item_lvl, @Item_amount=Item_amount , @Item_Hp=Hp 
	FROM INSERTED I
	JOIN Items It ON It.Item_ID=I.Item_ID;

	

    IF(EXISTS(
		SELECT *
		FROM Inventory I
		WHERE I.Character_ID=@Character_ID AND I.Item_ID=@Item_ID AND I.Item_lvl=@Item_lvl
	))
	BEGIN

		DECLARE @Original_Item_amount INT
		SET @Original_Item_amount=(
			SELECT Item_amount
			FROM Inventory
			WHERE @Character_ID = Character_ID AND @Item_ID = Item_ID AND @Item_lvl = Item_lvl)


		IF(@Item_amount+@Original_Item_amount>0)
		BEGIN
			UPDATE Inventory
			SET Item_amount+=@Item_amount
			WHERE Character_ID=@Character_ID AND Item_ID=@Item_ID AND Item_lvl=@Item_lvl

			IF(@Item_Hp IS NOT NULL)
			BEGIN
				UPDATE Characters
				SET Max_hp+=@Item_lvl*@Item_amount*@Item_Hp
				WHERE Character_ID=@Character_ID
			END

		END ELSE BEGIN
			DELETE FROM Inventory
			WHERE Character_ID=@Character_ID AND Item_ID=@Item_ID AND Item_lvl=@Item_lvl
		END

	END ELSE BEGIN

		IF(@Item_amount>0)
		BEGIN
			INSERT INTO Inventory
			VALUES (@Character_ID, @Item_ID, @Item_lvl,@Item_amount)

			IF(@Item_Hp IS NOT NULL)
			BEGIN
				UPDATE Characters
				SET Max_hp+=@Item_lvl*@Item_amount*@Item_Hp
				WHERE Character_ID=@Character_ID
			END
		END
		
	END

END
GO

CREATE TRIGGER deleteItem ON Inventory
INSTEAD OF DELETE
AS BEGIN


	DECLARE @Character_ID INT;
	DECLARE @Item_ID INT;
    DECLARE @Item_lvl INT;
	DECLARE @Item_amount INT;
	DECLARE @Item_Hp INT;

    SELECT @Character_ID = Character_ID, @Item_ID=D.Item_ID, @Item_lvl = Item_lvl, @Item_amount=Item_amount , @Item_Hp=Hp 
	FROM DELETED D
	JOIN Items It ON It.Item_ID=D.Item_ID;

	
	IF(@Item_Hp IS NOT NULL)
	BEGIN
		UPDATE Characters
		SET Max_hp-=@Item_lvl*@Item_amount*@Item_Hp
		WHERE Character_ID=@Character_ID

	END

	DELETE FROM Inventory
	WHERE Character_ID=@Character_ID AND Item_ID=@Item_ID AND Item_lvl=@Item_lvl
END
GO

CREATE TRIGGER DeleteGuild ON Guilds
INSTEAD OF DELETE 
AS BEGIN

	DECLARE @Giuld_ID INT;
	SET @Giuld_ID =(
		SELECT Guild_ID
		FROM DELETED
	)
	UPDATE Characters
	SET Guild_ID=NULL
	WHERE Guild_ID=@Giuld_ID

	DELETE FROM Guilds
	WHERE Guild_ID=@Giuld_ID
END
GO


CREATE TRIGGER CreteGuild ON Guilds
AFTER INSERT
AS BEGIN

	DECLARE @Character_ID INT;
	DECLARE @Guild_ID INT;

	SET @Character_ID =(
		SELECT Guild_owner
		FROM INSERTED
	)
	
	
	SET @Guild_ID =(
		SELECT Guild_ID
		FROM INSERTED
	)
	
	EXEC AddMember @Character_ID=@Character_ID, @Guild_ID=@Guild_ID


END
GO

CREATE TRIGGER DeleteCharacter ON Characters
INSTEAD OF DELETE
AS BEGIN
	DECLARE @Character_ID INT
	DECLARE @Guild_ID INT

	SELECT @Character_ID = Character_ID, @Guild_ID=Guild_ID
	FROM DELETED;

	EXEC RemoveMember @Character_ID=@Character_ID , @Guild_ID=@Guild_ID

	DELETE FROM Inventory
	WHERE Character_ID=@Character_ID

	DELETE FROM Characters
	WHERE Character_ID=@Character_ID

END

GO