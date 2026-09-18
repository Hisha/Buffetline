# 🍽️ BuffetLine

**Smart food, drink, and Mage refreshment buttons for World of Warcraft 3.3.5a.**

BuffetLine is a lightweight consumable-management addon for **World of Warcraft: Wrath of the Lich King 3.3.5a (Build 12340)**.

It automatically finds the best usable food and drink in your bags, keeps Mage refreshments separate from ordinary consumables, and can even restock your normal food and drink when you visit a vendor.

No more digging through bags. No more wondering which stack the addon picked. No more leaving the inn with three drinks and a long flight ahead.

**Version 1.1.4**

---

## ✨ Features

### 🍖 Smart Food Selection

BuffetLine automatically scans your bags and selects the **best food your character can currently use**.

The Food button:

- Automatically updates as your inventory changes
- Respects item level requirements
- Prefers appropriate conjured Mage food when available
- Displays the total available quantity
- Updates when food is consumed, purchased, created, or removed

---

### 🥤 Smart Drink Selection

The Drink button does the same for mana-restoring drinks.

BuffetLine automatically:

- Finds usable drinks in your bags
- Selects the best available option
- Respects character level requirements
- Prefers appropriate conjured Mage water
- Displays the current quantity
- Updates automatically as your inventory changes

---

### 🧙 Mage Refreshments

Mage characters receive a dedicated **Mage Refreshment** button for the combined food-and-drink refreshments introduced in Wrath of the Lich King.

Supported refreshments include:

| Item | Minimum Level |
| --- | ---: |
| Conjured Mana Biscuit | 65 |
| Conjured Mana Strudel | 74 |
| Conjured Mana Strudel | 80 |

Combined refreshments are kept **exclusive to the Mage Refreshment button** rather than competing with the normal Food and Drink buttons.

When the widget is locked, the Mage button appears only when appropriate for the character.

When unlocked, the Mage slot remains visible as a positioning aid so the widget can be arranged without the other buttons jumping around.

---

## 🛒 Automatic Vendor Restocking

BuffetLine can automatically replenish your normal food and drink whenever you open a merchant who sells suitable consumables.

Set the amount you want to keep on hand and BuffetLine handles the rest.

For example:

```text
Food target:  40
Drink target: 40
```

If you arrive at an innkeeper with:

```text
Food:  20
Drink: 19
```

BuffetLine purchases enough of the best usable vendor food and drink to bring you back to your configured targets.

Vendor stack sizes are handled automatically.

### What BuffetLine will NOT buy

BuffetLine intentionally keeps vendor restocking separate from Mage-created consumables.

Auto-restock:

- ✅ Counts normal purchased Food
- ✅ Counts normal purchased Drink
- ✅ Chooses appropriate usable vendor items
- ✅ Handles merchant bundle quantities
- ❌ Does not purchase conjured items
- ❌ Does not count conjured food toward the Food restock target
- ❌ Does not count conjured water toward the Drink restock target
- ❌ Does not count combined Mage refreshments toward either target

Your Mage supplies remain Mage supplies. Your vendor supplies remain vendor supplies.

---

## 🧭 Widget Layout

BuffetLine uses a compact linked-button widget.

### Horizontal

```text
[Mage Refreshment] [Food] [Drink]
```

### Vertical

```text
[Mage Refreshment]
[Food]
[Drink]
```

The **Food button is the positional anchor**, which keeps the widget stable as Mage eligibility, inventory, lock state, or orientation changes.

The entire widget moves together.

---

## 🔒 Locking and Positioning

Unlock BuffetLine to drag the widget wherever you want it.

Once positioned, lock it to prevent accidental movement.

Locking affects **movement only** — the consumable buttons remain fully usable while the widget is locked.

BuffetLine remembers:

- Widget position
- Lock state
- Horizontal/vertical orientation
- Auto-restock setting
- Food restock target
- Drink restock target

Your configuration persists between sessions and `/reload`.

---

## ⚙️ Configuration

BuffetLine integrates with the standard Blizzard addon options interface.

Open:

**Interface → AddOns → BuffetLine**

From there you can configure:

- **Lock widget position**
- **Vertical layout**
- **Auto-restock Food and Drink at vendors**
- **Food restock target**
- **Drink restock target**
- **Reset position**

Restock targets may be set from **0 to 1000**.

A target of `0` disables purchasing for that consumable without requiring you to disable auto-restock entirely.

---

## ⌨️ Slash Commands

BuffetLine can also be controlled from chat.

```text
/buffetline
/bf
```

### Available Commands

| Command | Description |
| --- | --- |
| `/bf` | Open BuffetLine options |
| `/bf lock` | Lock the widget |
| `/bf unlock` | Unlock the widget |
| `/bf horizontal` | Use horizontal layout |
| `/bf vertical` | Use vertical layout |
| `/bf restock` | Toggle automatic restocking |
| `/bf restock 1` | Enable automatic restocking |
| `/bf restock 0` | Disable automatic restocking |
| `/bf food N` | Set the Food restock target |
| `/bf drink N` | Set the Drink restock target |
| `/bf reset` | Reset the widget position |

Examples:

```text
/bf food 40
/bf drink 40
/bf restock 1
```

---

## 🖱️ Using the Buttons

BuffetLine is designed to stay out of the way during normal play.

Both **left-click and right-click** can use the consumable assigned to a button.

The buttons automatically update when your bags change, so there is no need to manually assign consumables to the bar.

If a better usable item becomes available, BuffetLine selects it automatically.

---

## 🧠 Consumable Priority

BuffetLine does more than simply grab the first food or drink it finds.

Selection considers:

1. Whether the character can currently use the item
2. The item's required level
3. The quality/usefulness of the available consumables
4. Whether an appropriate conjured alternative exists
5. Whether the item belongs exclusively to the Mage Refreshment category

**Stack size does not determine which consumable is considered best.**

A stack of 100 weaker drinks will not beat a stack of 5 better drinks simply because there are more of them.

The displayed count tells you how many you have — it does not influence selection priority.

---

## 📦 Installation

Copy the `BuffetLine` directory into:

```text
World of Warcraft/Interface/AddOns/
```

The resulting structure should look like:

```text
Interface/
└── AddOns/
    └── BuffetLine/
        ├── BuffetLine.toc
        ├── Core.lua
        ├── Options.lua
        ├── Restock.lua
        └── ...
```

Start World of Warcraft and make sure **BuffetLine** is enabled from the AddOns screen.

BuffetLine targets the original **World of Warcraft 3.3.5a client, Build 12340**.

---

## 💾 Saved Variables

BuffetLine stores its configuration using WoW's SavedVariables system.

Settings are character-independent unless otherwise specified by the addon configuration and survive normal logout, client restart, and `/reload`.

There is no external configuration file to maintain.

---

## 🧪 Version 1.1.4

Version **1.1.4** represents the completed consumable-selection and vendor-restocking foundation for BuffetLine.

Highlights include:

- Smart Food selection
- Smart Drink selection
- Dedicated Mage Refreshment handling
- Conjured food and water prioritization
- Level-aware consumable selection
- Stable linked-button positioning
- Horizontal and vertical layouts
- Persistent widget positioning
- Persistent addon settings
- Blizzard Interface Options integration
- Configurable Food and Drink restock targets
- Automatic vendor restocking
- Merchant bundle-size handling
- Protection against conjured items affecting vendor restock calculations
- Secure left/right-click consumable use
- Clean 3.3.5a-compatible implementation

---

## 🎯 Design Philosophy

BuffetLine has one job:

> **Put the consumable you actually want in front of you and keep enough of it in your bags.**

It isn't intended to replace your action bars, inventory addon, or Mage utilities.

It's the buffet line.

Grab your food. Grab your drink. Get back to killing things.

---

## ⚔️ Compatibility

BuffetLine is developed for:

**World of Warcraft: Wrath of the Lich King**  
**Client Version:** 3.3.5a  
**Client Build:** 12340

It is developed and tested against a 3.3.5a environment and does not depend on Retail WoW APIs.

---

## 📜 License

See the repository's `LICENSE` file for licensing information.

---

**BuffetLine v1.1.4**  
*Food. Drink. Refreshments. Adventure.*