from utility import *

cls()

# normalnie użytkownik wpisuje sam login i hasło
player_id = login('email1@wp.pl', 'password 123')

print('Dstępne postaci: ')
characters = get_characters(player_id)

nick, char_id = None, None
for index, row in characters.iterrows():
    print(row['Nick'])
    if not nick:
        pass
        nick = str(row['Nick'])
        char_id = int(row['Character_ID'])

wait()

print(f'Wybrano postać o nicku {nick}')

wait()

print('Otwarcie sklepu - store [id sklepu]')
print('Zaatakowanie potwora - attack [id potwora]')
print('Przejście do lokacji - move [id lokacji]')
print('Sprawdzenie ekwipunku - show eq')
print('id sklepu / potwora / lokacji znajduje się najbardziej po prawej stronie')

wait()

while True:
    location = get_location_id(char_id)
    # NPC
    print('Postacie w tej lokacji: ')
    npcs = get_friends(location)
    store_ids = {}
    for index, npc in npcs.iterrows():
        print(f"{npc['Name']} --- {int(npc['Store_ID']) if not pd.isnull(npc['Store_ID']) else 'Brak sklepu'}")
    # PRZECIWNICY
    print('Przeciwnicy w tej lokacji: ')
    enemies = get_enemies(location)
    enemies_ids = {}
    for index, enemy in enemies.iterrows():
        print(f"{enemy['Name']} --- {enemy['Enemy_ID']}")
        enemies_ids[enemy['Enemy_ID']] = index
    # LOKACJE
    print('Sąsiednie lokacje: ')
    locations = get_near_locations(char_id)
    for index, loc in locations.iterrows():
        print(f"{loc['Name']} --- {loc['Location_lvl']} poziom --- {loc['Location_ID']}")

    command = input('Polecenie: ').split(' ')
    cls()
    if command[0] == 'attack':
        enemy_pos = enemies_ids[int(command[1])]
        stats = get_enemy_stats(enemies.at[enemy_pos, 'Enemy_ID'])
        print(f'przeciwnik: {enemies.at[enemy_pos, "Name"]}:')
        print(f"zdrowie: {stats.at[0, 'Hp']}")
        print(f"obrona: {stats.at[0, 'Defence']}")
        print(f"atak: {stats.at[0, 'Attack']}")
        print('---------------------------')
        character_stats = get_character_stats(char_id)
        a, d = get_player_atk_def_hp(char_id)
        print(f'gracz: {nick}')
        print(f"zdrowie: {character_stats.at[0, 'Hp']}/{character_stats.at[0, 'Max_hp']}")
        print(f"obrona: {5 + d}")
        print(f"atak: {5 + a}")
        wait()
        damage_character(char_id, 10)  # powinno byc uzaleznione od potwora
        character_stats = get_character_stats(char_id)
        if int(character_stats.at[0, 'Hp']) > 0:
            print(f"Walka zakończona. Wygrywa {nick}.")
            give_award(char_id, enemies.at[enemy_pos, 'Enemy_ID'], location, enemies.at[enemy_pos, 'Kill_exp'])
        else:
            print(f"Walka zakończona. Wygrywa {enemies.at[enemy_pos, 'Name']}")
            die(char_id)
    elif command[0] == 'show' and command[1] == 'eq':
        items = get_player_eq(char_id)
        for index, item in items.iterrows():
            print(f"{index + 1}. {item['Name']} {item['Item_lvl']} --- {item['Item_amount']} sztuk")
    elif command[0] == 'store':
        store_id = int(command[1])
        items = get_store(store_id)
        for index, item in items.iterrows():
            print(f"{index + 1}. {item['Name']} --- {item['Item_lvl']} poziom --- {item['Amount']} sztuk"
                  f" --- {item['Unit_cost']} złota / szt")
    elif command[0] == 'move':
        dest = int(command[1])
        move_to_location(char_id, dest)
    elif command[0] == 'exit':
        break
    wait()
