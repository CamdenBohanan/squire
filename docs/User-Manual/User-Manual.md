# ⚔️ Army List Tracker: User Manual

## 1. Initial Setup and Launch

Before starting the application, you must launch the backend service to ensure database connectivity.

### A. Starting the Backend Service (Database Connection)

1.  Open your **Terminal** or **Command Prompt** within the root directory of the project.
2.  Run the following command to start the database connection service:

    ```bash
    dart run lib/data/services/Army_backend.dart
    ```

    > ⚠️ **Note:** Keep this terminal window open. The application will not function without the backend service running and connected to the database.

### B. Launching the Application (Front-end)

1.  Open a **second Terminal** or **Command Prompt** within the project's root directory.
2.  Run the standard Flutter command to launch the application:

    ```bash
    flutter run
    ```


---

## 2. Importing Your Army List

Once the application launches, you will be taken to the **Home Screen** where you input your army roster.

### A. Required List Format

You must paste or type your army list into the provided text box using the **exact format** shown below.

You can **type this out** or export it directly from the builder at **`https://builder.asoiaf.fr/`**.

**Example Format:**

Faction : TARGARYEN
Commander : Khal Drogo - The Great Khal
Points : 40 | 3/4 Attachments | 0 Neutral (0.00%)
Activations : 7


Units :
• Drogo's Bloodriders (8)
   with Khal Drogo - The Great Khal (0)
• Dothraki Outriders (6)
   with Outrider KO (1)
• Dothraki Veterans (8)
   with Jorah Mormont - The Exiled Knight (1)
• Dothraki Screamers (6)
   with Screamer KO (1)
• Freedmen (3)


Non-Combat Unit :
• Daenerys Targaryen - Khaleesi (4)
• Barristan Selmy - Advisor to the Dragon (5)


### B. Submitting the List

1.  Paste your complete list into the input box on the Home Screen.
2.  Click the **Submit** button to parse the list and proceed to the Tactical View.

---

## 3. Using the Tactical View (In-Game Tracking)

The Tactical View is the main screen for managing your ongoing game state.

* You can track how many **units you have activated** during the round.
* Click on a **Unit's Portrait** to enter the **Unit Detail Screen** for wounds and combat resolution.

---

## 4. Unit Detail Screen (Combat and Damage)

This screen provides tools for managing a single unit's combat status.

* **Wounds Tracking:** Use the controls to accurately track the **wounds** your unit has sustained.
* **Dice Rolling Tools:** You can roll for your **attacks**, **defense saves**, and **morale check**.
* **Clickable Modifiers:** Use the **clickable modifiers** to instantly adjust the dice roll result based on in-game effects, making combat resolution much faster.

You can continue this process for your entire game, managing activations, damage, and combat rolls until the game is complete.