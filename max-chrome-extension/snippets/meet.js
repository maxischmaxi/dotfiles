// Google Meet Standup Snippet
// Usage: Chrome DevTools > Sources > Snippets > Run (Ctrl+Enter)
(async () => {
  "use strict";

  // ═══════════════════════════════════════════════════════════════════
  // CONFIG
  // ═══════════════════════════════════════════════════════════════════
  const CONFIG = {
    // Set to true to only log the formatted message without sending
    DRY_RUN: false,
    // Set to true to scan the DOM for available selectors instead of running the workflow
    DISCOVERY_MODE: false,

    MESSAGE_PREFIX: "Standup Teilnehmer:",

    TIMEOUTS: {
      ELEMENT_WAIT: 5000,
      PANEL_ANIMATION: 800,
      AFTER_CLICK: 500,
      AFTER_SEND: 1000,
      HOVER_SETTLE: 600,
      POLL_INTERVAL: 200,
    },

    // Suffixes to strip from participant names
    NAME_SUFFIXES:
      /\s*\((You|Ich|Du|Präsentation|Presentation|Host|Organiser|Organisator)\)\s*$/gi,

    // Patterns to extract names from aria-labels on video tile buttons (DE + EN)
    NAME_EXTRACTION_PATTERNS: [
      // "Martin Senk an meinen Hauptbildschirm anpinnen"
      /^(.+?)\s+an\s+meine[n]?\s+Hauptbildschirm\s+anpinnen$/i,
      // "Pin Martin Senk to main screen"
      /^Pin\s+(.+?)\s+to\s+main\s+screen$/i,
      // "Weitere Optionen für „Martin Senk"" — use \W* to match any quote style
      /^Weitere\s+Optionen\s+f.r\s+\W*(.+?)\W*$/i,
      // "More options for "Martin Senk""
      /^More\s+options\s+for\s+\W*(.+?)\W*$/i,
      // "Mikrofon von Martin Senk stummschalten"
      /^Mikrofon\s+von\s+(.+?)\s+stummschalten$/i,
      // "Mute Martin Senk"
      /^Mute\s+(.+?)$/i,
    ],

    SELECTORS: {
      // Chat button
      CHAT_BUTTON: [
        {
          type: "aria",
          pattern: /^mit allen chatten$|^chat with everyone$|^chat$/i,
        },
        { type: "css", selector: 'button[data-panel-id="2"]' },
      ],
      // Chat input (appears after chat panel opens)
      CHAT_INPUT: [
        { type: "css", selector: 'textarea[jsname="YPqjbf"]' },
        { type: "css", selector: 'textarea[aria-label*="nachricht" i]' },
        { type: "css", selector: 'textarea[aria-label*="chat" i]' },
        {
          type: "css",
          selector: 'div[g_editable="true"][contenteditable="true"]',
        },
        {
          type: "aria",
          pattern:
            /verlauf ist aktiviert|history is on|send a message|nachricht senden/i,
        },
        { type: "css", selector: 'div[contenteditable="true"][aria-label]' },
        { type: "css", selector: 'div[contenteditable="true"]' },
      ],
      // Send button (use jsname or specific CSS to avoid matching the textarea)
      SEND_BUTTON: [
        { type: "css", selector: 'button[jsname="SoqoBf"]' },
        { type: "css", selector: 'button[aria-label="Nachricht senden"]' },
        { type: "css", selector: 'button[aria-label="Send a message"]' },
        {
          type: "css",
          selector:
            'button[aria-label*="send" i]:not([aria-label*="Reaktion" i])',
        },
      ],
      // Chat messages (to find the last own message for pinning)
      CHAT_MESSAGES: [
        { type: "css", selector: "div[data-sender-id]" },
        { type: "css", selector: "div[data-message-id]" },
      ],
    },
  };

  // ═══════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════
  const PREFIX = "[Standup]";

  function log(...args) {
    console.log(PREFIX, ...args);
  }

  function warn(...args) {
    console.warn(PREFIX, ...args);
  }

  function error(...args) {
    console.error(PREFIX, ...args);
  }

  function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  function findElement(strategies) {
    for (const strategy of strategies) {
      let el = null;
      if (strategy.type === "aria") {
        el = findByAriaLabel(strategy.pattern);
      } else if (strategy.type === "css") {
        el = document.querySelector(strategy.selector);
      }
      if (el) return el;
    }
    return null;
  }

  function findAllElements(strategies) {
    for (const strategy of strategies) {
      let els = [];
      if (strategy.type === "aria") {
        els = findAllByAriaLabel(strategy.pattern);
      } else if (strategy.type === "css") {
        els = Array.from(document.querySelectorAll(strategy.selector));
      }
      if (els.length > 0) return els;
    }
    return [];
  }

  function findByAriaLabel(pattern) {
    for (const el of document.querySelectorAll("[aria-label]")) {
      if (pattern.test(el.getAttribute("aria-label"))) return el;
    }
    return null;
  }

  function findAllByAriaLabel(pattern) {
    return Array.from(document.querySelectorAll("[aria-label]")).filter((el) =>
      pattern.test(el.getAttribute("aria-label")),
    );
  }

  async function waitForElement(
    strategies,
    timeout = CONFIG.TIMEOUTS.ELEMENT_WAIT,
  ) {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
      const el = findElement(strategies);
      if (el) return el;
      await sleep(CONFIG.TIMEOUTS.POLL_INTERVAL);
    }
    return null;
  }

  function simulateClick(el) {
    // Use native .click() first — Google Meet's Closure jsaction handlers
    // often only respond to native click events, not synthetic MouseEvents
    el.click();
    // Also dispatch full pointer/mouse chain for elements that need it
    const rect = el.getBoundingClientRect();
    const x = rect.left + rect.width / 2;
    const y = rect.top + rect.height / 2;
    const opts = { bubbles: true, cancelable: true, clientX: x, clientY: y };
    el.dispatchEvent(new PointerEvent("pointerdown", opts));
    el.dispatchEvent(new MouseEvent("mousedown", opts));
    el.dispatchEvent(new PointerEvent("pointerup", opts));
    el.dispatchEvent(new MouseEvent("mouseup", opts));
    el.dispatchEvent(new MouseEvent("click", opts));
  }

  function simulateHover(el) {
    const rect = el.getBoundingClientRect();
    const x = rect.left + rect.width / 2;
    const y = rect.top + rect.height / 2;
    const opts = { bubbles: true, cancelable: true, clientX: x, clientY: y };
    el.dispatchEvent(new PointerEvent("pointerover", opts));
    el.dispatchEvent(
      new PointerEvent("pointerenter", { ...opts, bubbles: false }),
    );
    el.dispatchEvent(new MouseEvent("mouseover", opts));
    el.dispatchEvent(new MouseEvent("mouseenter", { ...opts, bubbles: false }));
    el.dispatchEvent(new PointerEvent("pointermove", opts));
    el.dispatchEvent(new MouseEvent("mousemove", opts));
  }

  function typeIntoContentEditable(el, text) {
    el.focus();

    // For textarea/input: use native value setter to bypass framework wrappers,
    // then fire input event so Closure jsaction handlers update internal state
    if (el.tagName === "TEXTAREA" || el.tagName === "INPUT") {
      const proto =
        el.tagName === "TEXTAREA"
          ? HTMLTextAreaElement.prototype
          : HTMLInputElement.prototype;
      const nativeSetter = Object.getOwnPropertyDescriptor(proto, "value")?.set;
      if (nativeSetter) {
        nativeSetter.call(el, text);
      } else {
        el.value = text;
      }
      el.dispatchEvent(new Event("input", { bubbles: true }));
      el.dispatchEvent(new Event("change", { bubbles: true }));
      log("Text inserted via native textarea setter");
      return true;
    }

    // For contenteditable elements:
    // Tier 1: execCommand insertText
    const success = document.execCommand("insertText", false, text);
    if (success && (el.textContent || "").includes(text.substring(0, 20))) {
      log("Text inserted via execCommand");
      return true;
    }

    // Tier 2: Clipboard API paste simulation
    try {
      const dt = new DataTransfer();
      dt.setData("text/plain", text);
      const pasteEvent = new ClipboardEvent("paste", {
        bubbles: true,
        cancelable: true,
        clipboardData: dt,
      });
      el.dispatchEvent(pasteEvent);
      if ((el.textContent || "").includes(text.substring(0, 20))) {
        log("Text inserted via paste event");
        return true;
      }
    } catch (e) {
      warn("Paste simulation failed:", e.message);
    }

    // Tier 3: Direct textContent set + synthetic events
    el.textContent = text;
    el.dispatchEvent(new Event("input", { bubbles: true }));
    el.dispatchEvent(new Event("change", { bubbles: true }));
    log("Text inserted via direct content set");
    return true;
  }

  // ═══════════════════════════════════════════════════════════════════
  // DISCOVERY MODE
  // ═══════════════════════════════════════════════════════════════════
  function runDiscoveryMode() {
    log("=== DISCOVERY MODE ===");

    const buttons = document.querySelectorAll("button[aria-label]");
    log(`Buttons with aria-label (${buttons.length}):`);
    buttons.forEach((btn) => {
      log(`  [button] aria-label="${btn.getAttribute("aria-label")}"`, btn);
    });

    const editables = document.querySelectorAll("[contenteditable]");
    log(`Contenteditable elements (${editables.length}):`);
    editables.forEach((el) => {
      log(
        `  [${el.tagName}] contenteditable="${el.getAttribute("contenteditable")}" aria-label="${el.getAttribute("aria-label") || ""}"`,
        el,
      );
    });

    const textareas = document.querySelectorAll("textarea");
    log(`Textareas (${textareas.length}):`);
    textareas.forEach((el) => {
      log(
        `  [textarea] aria-label="${el.getAttribute("aria-label") || ""}"`,
        el,
      );
    });

    const dataEls = document.querySelectorAll(
      "[data-participant-id], [data-sender-id], [data-message-id], [data-self-name], [data-panel-id]",
    );
    log(`Elements with relevant data-attributes (${dataEls.length}):`);
    dataEls.forEach((el) => {
      const attrs = Array.from(el.attributes)
        .filter((a) => a.name.startsWith("data-"))
        .map((a) => `${a.name}="${a.value}"`)
        .join(" ");
      log(`  [${el.tagName}] ${attrs}`, el);
    });

    log("--- Selector match check ---");
    for (const [name, strategies] of Object.entries(CONFIG.SELECTORS)) {
      const el = findElement(strategies);
      const all = findAllElements(strategies);
      log(`  ${name}: ${el ? "FOUND" : "NOT FOUND"} (${all.length} total)`);
    }

    // Test name extraction from aria-labels
    log("--- Name extraction test ---");
    const extractedNames = strategyAriaLabelExtraction();
    log(`  Extracted names (${extractedNames.length}):`, extractedNames);

    const closureKeys = Object.keys(window).filter((k) =>
      k.startsWith("closure_lm_"),
    );
    log(`closure_lm_* properties: ${closureKeys.length}`);
    closureKeys.forEach((k) => log(`  ${k}`));

    const listItems = document.querySelectorAll('[role="listitem"]');
    log(`Elements with role="listitem" (${listItems.length}):`);
    listItems.forEach((el) => {
      const text = el.textContent?.trim().substring(0, 80);
      log(`  [${el.tagName}] "${text}"`, el);
    });

    log("=== END DISCOVERY MODE ===");
  }

  // ═══════════════════════════════════════════════════════════════════
  // STEP 0: Close open side panels
  // ═══════════════════════════════════════════════════════════════════
  async function closeOpenPanels() {
    // When side panels (chat, people, etc.) are open, Google Meet shrinks
    // video tiles and removes overlay buttons, breaking name extraction.
    // Close any open panel to restore full tile view.
    const panelButtons = document.querySelectorAll("button[data-panel-id]");
    for (const btn of panelButtons) {
      // Check aria-expanded OR whether the panel content area is visible
      const isExpanded = btn.getAttribute("aria-expanded") === "true";
      const panelId = btn.getAttribute("aria-controls");
      const panelContent = panelId ? document.getElementById(panelId) : null;
      const hasVisibleContent =
        panelContent &&
        panelContent.offsetHeight > 0 &&
        panelContent.children.length > 0;
      if (isExpanded || hasVisibleContent) {
        log(
          `Closing open panel: ${btn.getAttribute("aria-label") || btn.getAttribute("data-panel-id")}`,
        );
        simulateClick(btn);
        await sleep(CONFIG.TIMEOUTS.PANEL_ANIMATION);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // STEP 1: Find participants
  // ═══════════════════════════════════════════════════════════════════
  async function findParticipants() {
    log("Step 1: Finding participants...");

    let names = [];

    // Strategy A: Extract names from aria-labels on video tile buttons (primary)
    names = strategyAriaLabelExtraction();
    if (names.length > 0) {
      log(
        `Strategy A (aria-label extraction) found ${names.length} participants`,
      );
      return postProcessNames(names);
    }

    // Strategy B: Read names from video tile text content
    names = strategyTileTextContent();
    if (names.length > 0) {
      log(`Strategy B (tile text content) found ${names.length} participants`);
      return postProcessNames(names);
    }

    // Strategy C: data-self-name attribute
    names = strategyDataSelfName();
    if (names.length > 0) {
      log(`Strategy C (data-self-name) found ${names.length} participants`);
      return postProcessNames(names);
    }

    // Strategy D: closure state introspection
    names = strategyClosureState();
    if (names.length > 0) {
      log(`Strategy D (closure state) found ${names.length} participants`);
      return postProcessNames(names);
    }

    throw new Error(
      "Could not find any participants. Run with DISCOVERY_MODE = true to debug selectors.",
    );
  }

  /**
   * Strategy A: Extract participant names from aria-labels on video tile buttons.
   * Google Meet decorates buttons with labels like:
   *   "Martin Senk an meinen Hauptbildschirm anpinnen"
   *   "Weitere Optionen für „Julia Krüger""
   *   "Mikrofon von Oliver Zils stummschalten"
   */
  function strategyAriaLabelExtraction() {
    const names = new Set();
    const allLabeled = document.querySelectorAll("button[aria-label]");

    for (const el of allLabeled) {
      const label = el.getAttribute("aria-label");
      for (const pattern of CONFIG.NAME_EXTRACTION_PATTERNS) {
        // Reset lastIndex for patterns with global flag
        pattern.lastIndex = 0;
        const match = label.match(pattern);
        if (match && match[1]) {
          const name = match[1].trim();
          // Filter out labels that are clearly not participant names
          if (name.length > 0 && name.length < 60) {
            names.add(name);
          }
          break;
        }
      }
    }

    return Array.from(names);
  }

  /**
   * Strategy B: Read participant names from video tile text content.
   * Each tile (div[data-participant-id]) contains the participant's name
   * as visible text, even when overlay buttons are hidden (small tile mode).
   */
  function strategyTileTextContent() {
    const tiles = document.querySelectorAll("[data-participant-id]");
    const names = [];
    for (const tile of tiles) {
      // The name is typically in a nested div/span — look for the shortest
      // meaningful text node that isn't a button label or status text
      let name = "";
      // Try jsname="V0eDbc" or similar name container (common in Meet tiles)
      const nameEl =
        tile.querySelector('[jsname="V0eDbc"]') ||
        tile.querySelector("[data-self-name]");
      if (nameEl) {
        name = nameEl.textContent?.trim() || "";
      }
      // Fallback: find the name in the aria-label of the tile itself
      if (!name) {
        const tileLabel = tile.getAttribute("aria-label");
        if (tileLabel) name = tileLabel.trim();
      }
      // Last resort: scan for a short text element that looks like a name
      if (!name) {
        const candidates = tile.querySelectorAll("div, span");
        for (const c of candidates) {
          const text = c.textContent?.trim() || "";
          // Name-like: 2-50 chars, no special UI text
          if (
            text.length >= 2 &&
            text.length <= 50 &&
            c.children.length === 0 &&
            !/stummgeschaltet|muted|präsentiert|presenting|neuer bildausschnitt|new frame|hintergr|background|effekte|effects|bildschirm|screen/i.test(
              text,
            )
          ) {
            name = text;
            break;
          }
        }
      }
      if (name) names.push(name);
    }
    return names;
  }

  function strategyDataSelfName() {
    const els = document.querySelectorAll("div[data-self-name]");
    return Array.from(els)
      .map((el) => el.getAttribute("data-self-name")?.trim() || "")
      .filter((n) => n.length > 0);
  }

  function strategyClosureState() {
    const names = [];
    const closureKeys = Object.keys(window).filter((k) =>
      k.startsWith("closure_lm_"),
    );
    for (const key of closureKeys) {
      try {
        const obj = window[key];
        if (!obj || typeof obj !== "object") continue;
        for (const prop of Object.keys(obj)) {
          const val = obj[prop];
          if (Array.isArray(val)) {
            for (const item of val) {
              if (
                item &&
                typeof item === "object" &&
                typeof item.name === "string"
              ) {
                names.push(item.name);
              }
            }
          }
        }
      } catch {
        // Ignore access errors on closure objects
      }
    }
    return names;
  }

  function postProcessNames(names) {
    return [
      ...new Set(
        names
          .map((n) => n.replace(CONFIG.NAME_SUFFIXES, "").trim())
          .filter((n) => n.length > 0),
      ),
    ].sort((a, b) => a.localeCompare(b, "de"));
  }

  // ═══════════════════════════════════════════════════════════════════
  // STEP 2: Format message
  // ═══════════════════════════════════════════════════════════════════
  const EMOJIS = [
    "🎯",
    "🚀",
    "⚡",
    "🔥",
    "✨",
    "🌟",
    "💡",
    "🎲",
    "🎪",
    "🏆",
    "🦊",
    "🐼",
    "🦄",
    "🐸",
    "🦁",
    "🐧",
    "🦋",
    "🐝",
    "🦈",
    "🐙",
    "🌈",
    "🌻",
    "🍀",
    "🌵",
    "🎸",
    "🎨",
    "🧩",
    "🛸",
    "⛵",
    "🏔️",
    "🍕",
    "🍩",
    "🧁",
    "☕",
    "🍉",
    "🥑",
    "🌮",
    "🍿",
    "🧀",
    "🥨",
  ];

  function randomEmoji() {
    return EMOJIS[Math.floor(Math.random() * EMOJIS.length)];
  }

  function formatMessage(names) {
    log("Step 2: Formatting message...");
    const used = new Set();
    const lines = names.map((n) => {
      let emoji;
      do {
        emoji = randomEmoji();
      } while (used.has(emoji) && used.size < EMOJIS.length);
      used.add(emoji);
      return `- ${n} ${emoji}`;
    });
    return `${CONFIG.MESSAGE_PREFIX}\n${lines.join("\n")}`;
  }

  // ═══════════════════════════════════════════════════════════════════
  // STEP 3: Send chat message
  // ═══════════════════════════════════════════════════════════════════
  async function sendChatMessage(message) {
    log("Step 3: Sending chat message...");

    // Ensure chat panel is open
    let chatInput = findElement(CONFIG.SELECTORS.CHAT_INPUT);
    if (!chatInput) {
      const chatBtn = findElement(CONFIG.SELECTORS.CHAT_BUTTON);
      if (!chatBtn) throw new Error("Chat button not found");
      log("Opening chat panel...");
      simulateClick(chatBtn);
      await sleep(CONFIG.TIMEOUTS.PANEL_ANIMATION);
      chatInput = await waitForElement(CONFIG.SELECTORS.CHAT_INPUT);
      // Retry once if first click didn't register
      if (!chatInput) {
        log("Chat input not found, retrying click...");
        simulateClick(chatBtn);
        await sleep(CONFIG.TIMEOUTS.PANEL_ANIMATION);
        chatInput = await waitForElement(CONFIG.SELECTORS.CHAT_INPUT);
      }
    }
    if (!chatInput) throw new Error("Chat input not found");

    log("Chat input found, inserting text...");
    typeIntoContentEditable(chatInput, message);
    await sleep(CONFIG.TIMEOUTS.AFTER_CLICK);

    // Try send button first, fall back to Enter key
    const sendBtn = findElement(CONFIG.SELECTORS.SEND_BUTTON);
    if (sendBtn) {
      log("Clicking send button");
      simulateClick(sendBtn);
    } else {
      log("Send button not found, pressing Enter");
      chatInput.dispatchEvent(
        new KeyboardEvent("keydown", {
          key: "Enter",
          code: "Enter",
          bubbles: true,
        }),
      );
      chatInput.dispatchEvent(
        new KeyboardEvent("keyup", {
          key: "Enter",
          code: "Enter",
          bubbles: true,
        }),
      );
    }

    await sleep(CONFIG.TIMEOUTS.AFTER_SEND);

    // Verify message was sent (input should be empty)
    const remaining = (chatInput.textContent || chatInput.value || "").trim();
    if (remaining.length > 0) {
      warn(
        "Chat input is not empty after sending — message may not have been sent",
      );
    } else {
      log("Message sent successfully");
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // STEP 4: Pin message (non-critical)
  // ═══════════════════════════════════════════════════════════════════
  async function pinLastMessage() {
    log("Step 4: Pinning message...");

    try {
      // Find chat messages — try multiple approaches
      let messages = findAllElements(CONFIG.SELECTORS.CHAT_MESSAGES);

      // Fallback: find message containers inside the chat panel
      if (messages.length === 0) {
        const chatPanel = document.querySelector('div[data-panel-id="2"]');
        if (chatPanel) {
          // Look for the side panel content area that contains messages
          const panel = chatPanel.closest("[aria-controls]")
            ? document.getElementById(
                chatPanel
                  .closest("[aria-controls]")
                  ?.getAttribute("aria-controls"),
              )
            : document.getElementById("ME4pNd");
          if (panel) {
            // Chat messages are typically in divs with specific structure
            messages = Array.from(
              panel.querySelectorAll(
                "div[data-sender-id], div[data-message-id]",
              ),
            );
          }
        }
      }

      if (messages.length === 0) {
        warn(
          "No chat messages found for pinning — trying hover on last chat bubble",
        );
        // Try to find any message-like container in the chat area
        const chatArea = document.getElementById("ME4pNd");
        if (chatArea) {
          // Look for elements that look like messages (have some depth and text)
          const candidates = chatArea.querySelectorAll("div[tabindex]");
          messages = Array.from(candidates);
        }
      }

      if (messages.length === 0) {
        warn("No chat messages found for pinning");
        return;
      }

      const lastMessage = messages[messages.length - 1];
      log("Hovering over last message to reveal action buttons...");
      simulateHover(lastMessage);
      await sleep(CONFIG.TIMEOUTS.HOVER_SETTLE);

      // Look for pin button that appears on hover
      // Important: avoid matching video tile "anpinnen" buttons — chat pin buttons
      // are inside the chat panel area, so scope the search
      let pinBtn = null;
      const chatPanel = document.getElementById("ME4pNd");
      if (chatPanel) {
        for (const btn of chatPanel.querySelectorAll("button[aria-label]")) {
          const label = btn.getAttribute("aria-label");
          if (/pin|anpinnen/i.test(label) && !/Hauptbildschirm/i.test(label)) {
            pinBtn = btn;
            break;
          }
        }
      }

      // Sometimes the pin action is in a "more actions" menu on the message
      if (!pinBtn) {
        const moreBtn = chatPanel
          ? chatPanel.querySelector(
              'button[aria-label*="Weitere" i], button[aria-label*="More" i]',
            )
          : findByAriaLabel(/more\s*actions|weitere\s*aktionen/i);
        if (moreBtn) {
          log("Opening message actions menu...");
          simulateClick(moreBtn);
          await sleep(CONFIG.TIMEOUTS.AFTER_CLICK);
          // Now look for pin in the popup menu
          pinBtn = findByAriaLabel(/^pin$|^anpinnen$/i);
          if (!pinBtn) {
            // Try any menu item containing "pin"
            for (const item of document.querySelectorAll(
              '[role="menuitem"], [role="option"]',
            )) {
              if (/pin|anpinnen/i.test(item.textContent)) {
                pinBtn = item;
                break;
              }
            }
          }
        }
      }

      if (!pinBtn) {
        warn("Pin button not found — skipping pinning");
        return;
      }

      log("Clicking pin button...");
      simulateClick(pinBtn);
      await sleep(CONFIG.TIMEOUTS.AFTER_CLICK);

      // Handle potential confirmation dialog
      const dialog = document.querySelector(
        '[role="dialog"]:not([aria-hidden="true"])',
      );
      if (dialog) {
        const confirmBtn = dialog.querySelector(
          'button[aria-label*="pin" i], button[aria-label*="anpinnen" i]',
        );
        if (confirmBtn) {
          log("Confirming pin dialog...");
          simulateClick(confirmBtn);
          await sleep(CONFIG.TIMEOUTS.AFTER_CLICK);
        }
      }

      log("Message pinned successfully");
    } catch (e) {
      warn("Pinning failed (non-critical):", e.message);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MAIN
  // ═══════════════════════════════════════════════════════════════════
  async function main() {
    log("Starting...");

    if (CONFIG.DISCOVERY_MODE) {
      runDiscoveryMode();
      return;
    }

    // Step 0: Close any open side panels to restore full video tile view
    await closeOpenPanels();

    // Step 1: Find participants
    const names = await findParticipants();
    log(`Found ${names.length} participants:`, names);
    if (names.length === 0) {
      throw new Error("No participants found");
    }

    // Step 2: Format message
    const message = formatMessage(names);
    log("Formatted message:\n" + message);

    if (CONFIG.DRY_RUN) {
      log("DRY_RUN enabled — not sending message");
      return;
    }

    // Step 3: Send message
    await sendChatMessage(message);

    // Step 4: Pin message (non-critical)
    await pinLastMessage();

    log("Done!");
  }

  try {
    await main();
  } catch (e) {
    error("Failed:", e.message);
    error("Tip: Run with DISCOVERY_MODE = true to debug selectors");
    throw e;
  }
})();
