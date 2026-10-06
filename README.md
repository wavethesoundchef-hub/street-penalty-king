# Neon Penalty Shootout

A 2D penalty shootout game made with [Phaser 3](https://phaser.io/). Everything is in one `index.html` file.

## Play

Open `index.html` in any modern browser. Phaser and the font load from a CDN, so you need an internet connection.

- **Flick** from the ball toward the goal. The direction of the flick aims the shot left or right.
- **Flick speed** sets power and height. Flick too hard and the ball goes over the bar.
- **Curve your swipe** to add spin. The ball bends late, which makes it harder for the keeper to read.
- You get 5 shots. The keeper gets quicker and sharper with each one.

## Tuning

- Keeper difficulty: `Keeper.configure()`
- How much height each bit of flick speed adds: the `lift` line in `GameScene.shoot()`
- How strong the curve is: the `curve` line in `GameScene.onUp()`
