import pyodbc
import os
import pandas as pd
from random import uniform as rand

with open('./server_name') as f:
    server = f.read()

conn = pyodbc.connect(
    'Driver={SQL Server};'
    f'Server={server};'
    'Database=Project;'
    'Trusted_Connection=yes;'
)


def cls():
    os.system('cls')


def wait():
    input('...')
    cls()


# FUNKCJE
def login(email, password):
    player_id = pd.read_sql_query(f'''
        SELECT dbo.TryToLogin(N'{email}', N'{password}')
    ''', conn)
    conn.commit()
    return int(player_id.iat[0, 0])


def register():
    cls()
    email = input('Email: ')
    password = input('Hasło: ')
    conn.execute(f'''
        EXEC Register @Email=N'{email}', @Password=N'{password}'
    ''')
    conn.commit()


def ban_player():
    cls()
    nick = input('Nick: ')
    duration = int(input('Duration: '))
    reason = input('Reason: ')
    conn.execute(f'''
        EXEC BanPlayer @Nick=N'{nick}', @Duration='{duration}', @Reason=N'{reason}'
    ''')
    conn.commit()


def get_banned_players():
    cls()
    banned = pd.read_sql_query(f"""
        SELECT * FROM CurrentlyBanned
    """, conn)
    for index, ban in banned.iterrows():
        print(f"{index + 1}. ID: {ban['Player_ID']} --- DO: {ban['Finish']} --- Za: {ban['Reason']}")
    wait()


def get_characters(player_id):
    characters = pd.read_sql(f'''
        SELECT * FROM dbo.PlayerCharacters('{player_id}')
    ''', conn)
    return characters


def get_friends(location_id):
    npcs = pd.read_sql_query(f'''
        SELECT * FROM dbo.FriendsInLocation('{location_id}')
    ''', conn)
    return npcs


def get_enemies(location_id):
    enemies = pd.read_sql_query(f'''
            SELECT * FROM dbo.EnemiesInLocation('{location_id}')
        ''', conn)
    return enemies


def get_enemy_stats(enemy_id):
    return pd.read_sql_query(f'''
        SELECT * FROM Enemies WHERE Enemy_ID={enemy_id}
    ''', conn)


def get_character_stats(character_id):
    return pd.read_sql_query(f'''
        SELECT * FROM Characters WHERE Character_ID={character_id}
    ''', conn)


def get_player_items(character_id):
    return pd.read_sql_query(f'''
        SELECT * FROM dbo.CharacterInventory({character_id}) Inv JOIN Items Ite ON Ite.Item_ID = Inv.Item_ID
    ''', conn)


def get_player_atk_def_hp(character_id):
    items = get_player_items(character_id)
    attack, defence = 0, 0
    for index, item in items.iterrows():
        if not pd.isnull(item['Attack']):
            attack += item['Attack'] * item['Item_amount'] * (1 if pd.isnull(item['Item_lvl']) else item['Item_lvl'])
        if not pd.isnull(item['Defence']):
            defence += item['Defence'] * item['Item_amount'] * (1 if pd.isnull(item['Item_lvl']) else item['Item_lvl'])
    return attack, defence


def damage_character(character_id, dmg):
    conn.execute(f"""
        UPDATE Characters SET Hp=Hp - {dmg} WHERE Character_ID={character_id}
    """)
    conn.commit()


# nie pewne czy dziala
def give_award(character_id, monster_id, location, exp):
    conn.execute(f"""
        EXEC Gain_Exp @Character_ID={character_id}, @Exp_gain={exp}
    """)
    loots = pd.read_sql_query(f"""
        SELECT * FROM EnemyDrops WHERE Enemy_ID={monster_id}
    """, conn)
    lvl = pd.read_sql_query(f"""
        SELECT Location_lvl FROM Locations WHERE Location_ID={location}
    """, conn).iat[0, 0]
    for index, loot in loots.iterrows():
        drop_coin = rand(0, 1)
        if float(loot['Drop_chance']) > drop_coin:
            conn.execute(f"""
                INSERT INTO Inventory(Character_ID, Item_ID, Item_lvl, Item_amount) VALUES
                ({character_id}, {loot['Item_ID']}, {lvl}, 1)
            """)
    conn.commit()


def die(character_id):
    conn.execute(f"""
        EXEC Death @Character_ID={character_id}
    """)
    conn.commit()


def get_player_eq(character_id):
    return pd.read_sql_query(f"""
        SELECT * FROM dbo.CharacterInventory({character_id})
    """, conn)


def get_store(store_id):
    return pd.read_sql_query(f"""
        SELECT * FROM dbo.ItemsInStore({store_id})
    """, conn)


def get_location_id(character_id):
    return int(pd.read_sql_query(f"""
        SELECT Location_ID FROM Characters WHERE Character_ID={character_id}
    """, conn).iat[0, 0])


def get_near_locations(character_id):
    return pd.read_sql_query(f"""
        SELECT * FROM AccessibleLocations({character_id})
    """, conn)


def move_to_location(character_id, location_id):
    conn.execute(f"""
        EXEC AttemptToMove @Character_ID={character_id}, @Destination_ID={location_id}
    """)
