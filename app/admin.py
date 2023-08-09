from utility import *

# menu
while True:
    cls()
    print('1. Zbanuj gracza')
    print('2. Pokaż zbanowanych graczy')
    print('3. Exit')
    choice = int(input('Wybierz opcje z listy: '))

    try:
        if choice == 1:
            ban_player()
        if choice == 2:
            get_banned_players()
        elif choice == 3:
            break
    except Exception:
        cls()
        print('Coś poszło nie tak')
        wait()
