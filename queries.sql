USE Project

-- 10 najlepszych postaci w grze (branie pod uwage wynikwo ex-aequo)
SELECT TOP 10 WITH TIES Nick, Lvl FROM Characters
ORDER BY Lvl DESC

--wypisywanie wszystkich postaci w lokacji o ID = 1
SELECT Player_ID, Character_ID, Nick, Lvl FROM Characters
WHERE Location_ID = 1

--wypisywanie lokacji w ktorych sa najsilniejsze potwory razem z potworami
SELECT TOP 1 WITH TIES L.Name AS Lokacja, L.Location_lvl AS Poziom, E.Name AS Enemy
FROM Locations L JOIN NPCs E ON L.Location_ID=E.Location_ID
WHERE E.NPC_ID IN (SELECT Enemy_ID FROM Enemies)
ORDER BY L.Location_lvl DESC


--wypisywanie wszystkich ofert w domu aukcyjnym razem z tym kto licytuje najwyzej
SELECT I.Name, A.Item_lvl, B.Bid_amount, C.Nick
FROM Items I JOIN AuctionHouse A ON I.Item_ID=A.Item_ID
JOIN AuctionHouseBids B ON A.Offer_ID=B.Offer_ID
JOIN Characters C ON C.Character_ID=B.Bidder_ID
WHERE C.Character_ID=(SELECT TOP 1 Bidder_ID FROM AuctionHouseBids WHERE Offer_ID=A.Offer_ID ORDER BY Bid_amount DESC)


--wypisanie wszystkich ktore daj¹ atak i ich statystyk
SELECT * FROM Items WHERE Attack IS NOT NULL

USE master