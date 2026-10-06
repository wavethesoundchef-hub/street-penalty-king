# Street Penalty King

A 2D street-football penalty shootout set on a Lagos street at dusk, made with [Phaser 3](https://phaser.io/). Everything is in one `index.html` file.

## Play

Open `index.html` in any modern browser. Phaser and the fonts (Anton, Montserrat) load from a CDN, so you need an internet connection.

- **Flick** from the ball toward the goal. The direction of the flick aims the shot left or right.
- **Flick speed** sets power and height. The power meter shows it while you drag; in the red, the ball starts going over the bar.
- **Curve your swipe** to add spin. The ball bends late, which makes it harder for the keeper to read.
- You get 5 shots. The keeper gets quicker and sharper with each one.

## Factions

The first time you open the game you choose **who you represent** and a nickname. Your faction is locked for 30 days (with one free switch), and every match you play counts for it on the global leaderboard. Before each match you pick **your opponent** (any faction, from any tab). The menu has three tabs:

- **Footballers:** Team CR7 vs Team Messi, Team Neymar vs Team Mbappé, Team Haaland vs Team Vini Jr, Team Osimhen vs Team Lookman, Team Okocha vs Team Kanu
- **Artistes:** Starboy FC (Wizkid) vs 30BG (Davido) vs Outsiders (Burna Boy), Afrorave (Rema) vs Ololade (Asake), Tems vs Ayra Starr, Kizz Daniel vs Fireboy DML, YBNL (Olamide) vs Seyi Vibez, Shallipopi vs Odumodublvck
- **Streets:** Mainland Giants vs Island Legends, Ikeja Eagles vs Ajegunle Stars, Kings of Calabar vs Jos Jets, Ibadan Warriors vs Abeokuta Rocks, PH City Oilers vs Abuja Capitals

What your pick changes:

- Your striker wears your faction's jersey with its name and number on the back (for example RONALDO 7, MESSI 10, 30BG 001, WIZKID FC 11). The menu shows a preview of the jersey as you choose.
- The keeper wears your chosen opponent's kit.
- The header shows both badges, your score and your goal streak, and goal pop-ups use your faction's chants and colours.
- Your choice is saved in the browser and preselected next time. Saving needs the game to be opened from a web address; when you open the file directly from your computer, the choice only lasts until you close the page.

## Global leaderboard

- **Factions:** ranked by average goals per match; a faction needs 10+ matches in the period to be ranked. Total goals and matches are shown too.
- **Rivalries:** head-to-head bars (CR7 vs Messi, Wizkid FC vs 30BG, Mainland vs Island, and so on).
- **Players:** the top 20 scorers.
- **This week / all time.** Weeks reset on Monday, Lagos time.
- Only your first 10 matches in any 24 hours count; after that matches are practice. Matches less than 12 seconds apart are rejected.

Players are anonymous: the game creates a hidden account on each phone, so there is no email or password. Clearing the browser data starts a new player.

### Setting up the leaderboard (once)

1. In your Supabase project, open **SQL Editor**, paste the contents of [`supabase/schema.sql`](supabase/schema.sql) and run it.
2. Go to **Authentication -> Sign In / Providers** and turn on **Allow anonymous sign-ins**.
3. In **Project Settings -> API**, copy the **Project URL** and the **anon public** key into the `SUPABASE` settings near the top of the script in `index.html`.

The anon key is designed to be public. The database exposes only the checked `spk_*` functions, so players can't edit the tables directly. Never put the **service_role** key in the game. Until the settings are filled in, the game runs offline and the leaderboard says it isn't connected.

## Play a friend

Tap **PLAY A FRIEND** in the menu:

- **Live match:** one player taps CREATE ROOM and shares the code or the WhatsApp invite; the other opens the link (or taps JOIN WITH CODE). You both take 5 shots at the same time, see each other's results live, and get a head-to-head result with a rematch button. Works on the same Wi-Fi or anywhere online. The two phones connect directly (WebRTC); the free public [PeerJS](https://peerjs.com/) server is only used to introduce them.
- **WhatsApp challenge:** take your 5 shots, then send the link. Your friend opens it, picks a side and tries to beat your score, then can send a reply link back. No server needed: the score travels inside the link.
- **Bluetooth** isn't available to web games, so phones can't pair over it directly.

Invite and challenge links only open for friends once the game is hosted online (for example on GitHub Pages). Room codes work anywhere.

## Certificate

After 5 shots you get a **Match Certificate** showing your faction vs your opponent, your score, and a stamp:

- 0 or 1 goals: a red DISGRACE TO FC 🤡 or SAPA FOOTBALL ❌ stamp
- 2 or 3 goals: E NEVER REACH or YOU TRY
- 4 or 5 goals: a glowing gold AGBA BALLER 🏆 or NO LELE 🔥 stamp

The commentary is written for your faction, your opponent and your score (for example, Wizkid FC on 0/5 against 30BG gets roasted about disgracing Starboy). **Challenge Rivals on WhatsApp** sends your score with a challenge link your opponent's fans can open and play.

This is a fan-made game. It isn't affiliated with or endorsed by any player, artist or club. The badges and jerseys are original drawings, not official logos or kits.

## Tuning

- Keeper difficulty: `Keeper.configure()`
- How much height each bit of flick speed adds: the `lift` line in `GameScene.shoot()`
- How strong the curve is: the `curve` line in `GameScene.onUp()`
- Factions (names, jersey names and numbers, colours, goal chants): `FACTIONS`
- Which factions appear in which menu tab and row: `TABS`
- Leaderboard rules (daily cap, rate limit, faction lock, ranking): `supabase/schema.sql`
- Certificate roasts and praise: `ROAST_OVERRIDES` (exact faction + score lines), `ROASTS` (templates), `HEROES` (names used in the templates), `stampFor()` (stamps)
