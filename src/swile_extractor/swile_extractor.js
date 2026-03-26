// "Forked" from and vibe coded over https://gist.github.com/paulchaum/51522a2a550244466fc4d104893c8fb2

// Load all transactions before running this script: there's logic to automate
// that but it not good enough yet (TODO), and pre-loading makes the script
// faster

// There are logs to monitor the extraction and validate the results
// Make sure to display all the necessary log levels to see them

// To stop the script before its end
// window.stopSwileExtraction = true

(async () => {
  // ===== TIMING CONFIGURATION (in seconds) =====
  const TIMING = {
    SCROLL_INTO_VIEW_DELAY: 0.050,      // Delay before clicking button
    POST_CLICK_DELAY: 0.150,            // Delay after clicking button
    MODAL_WAIT_INTERVAL: 0.020,         // Interval between modal checks
    MODAL_WAIT_MAX_ATTEMPTS: 20,        // Max attempts to wait for modal (20 * 0.1s = 2s)
    MODAL_CLOSE_CHECK_INTERVAL: 0.020,  // Interval between modal close checks
    MODAL_CLOSE_MAX_ATTEMPTS: 15,       // Max attempts to wait for modal close (15 * 0.05s = 0.75s)
    POST_CLOSE_DELAY: 0.100,            // Delay after modal close
    SCROLL_WAIT_DELAY: 1.500            // Delay to wait for new content after scroll
  };
  // =============================================

  const extractAmount = (amountStr) => {
    let regex;
    const language = navigator.language;
    if (language.includes("fr")) {
      // French
      // Replace all spaces with an empty string
      amountStr = amountStr.replace(/\s/g, '');
      regex = /(?<symbol>[-+])?\s*(?<amount>\d+,\d{2})?\s*(?<currency>€)?\s*/;
    } else {
      // English
      // Replace coma with an empty string
      amountStr = amountStr.replace(/,/g, '');
      regex = /(?<symbol>[-+])?\s*(?<currency>€)?\s*(?<amount>\d+\.\d{2})/;
    }
    const match = regex.exec(amountStr);

    // Check if a match was found before destructuring
    const {
      symbol,
      amount,
    } = match.groups;

    // Remove commas for correct parsing
    let amountNumber;
    if (language.includes("fr")) {
      // French
      amountNumber = parseFloat(amount.replace(/,/g, '.')) * (symbol === "-" ? -1 : 1);
    } else {
      // English
      amountNumber = parseFloat(amount.replace(/,/g, '')) * (symbol === "-" ? -1 : 1);
    }

    return amountNumber;
  };


  const extractDate = (dateStr) => {
    // Detect language
    const language = navigator.language;
    let months = [];
    let weekdays = [];
    let relativeDays = [];
    if (language.includes("fr")) {
      // French
      months = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"];
      weekdays = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"];
      relativeDays = ["Aujourd'hui", "Hier"];
    } else {
      // English
      months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
      weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
      relativeDays = ["Today", "Yesterday"];
    }

    // Helper to format a Date object to YYYY-MM-DD
    const toYYYYMMDD = (date) => {
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      return `${year}-${month}-${day}`;
    };

    // --- Main Logic ---

    // 1. Clean the input string
    const cleanedStr = dateStr.includes('•') ? dateStr.split('•')[1].trim() : dateStr.trim();
    const firstWord = cleanedStr.split(/[\s,]+/)[0];

    const today = new Date();
    // Set hours to 0 to compare dates without time influencing the result
    today.setHours(0, 0, 0, 0);

    // 2. Handle "Today" and "Yesterday"
    if (firstWord === relativeDays[0]) { // "Today"
      return toYYYYMMDD(today);
    }
    if (firstWord === relativeDays[1]) { // "Yesterday"
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      return toYYYYMMDD(yesterday);
    }

    // 3. Handle weekdays (e.g., "Monday", "Saturday")
    const weekdayIndex = weekdays.findIndex(day => day === firstWord);
    if (weekdayIndex !== -1) {
      const targetDate = new Date();
      const currentDay = targetDate.getDay();
      let daysToSubtract = currentDay - weekdayIndex;
      // If the day is today or in the future, assume it was last week
      if (daysToSubtract <= 0) {
        daysToSubtract += 7;
      }
      targetDate.setDate(targetDate.getDate() - daysToSubtract);
      return toYYYYMMDD(targetDate);
    }

    // 4. Handle month-based dates (e.g., "October 1" or "October 1, 2022")
    let monthStr;
    if (language.includes("fr")) {
      // French
      monthStr = cleanedStr.split(/[\s,]+/)[1];
    } else {
      // English
      monthStr = cleanedStr.split(/[\s,]+/)[0];
    }

    const monthIndex = months.findIndex(month => month === monthStr);
    if (monthIndex !== -1) {
      const parts = cleanedStr.split(/[\s,]+/);
      let day;
      if (language.includes("fr")) {
        // French
        day = parseInt(parts[0], 10);
      } else {
        // English
        day = parseInt(parts[1], 10);
      }
      // Check if a year is provided
      const yearStr = parts.find(p => /^\d{4}$/.test(p));

      if (yearStr) {
        // Full date like "September 22, 2023"
        const year = parseInt(yearStr, 10);
        return toYYYYMMDD(new Date(year, monthIndex, day));
      } else {
        // Partial date like "September 22", assume year
        const targetDate = new Date(today.getFullYear(), monthIndex, day);
        targetDate.setHours(0, 0, 0, 0);
        // If the parsed date is in the future, assume it was from the previous year
        if (targetDate > today) {
          targetDate.setFullYear(targetDate.getFullYear() - 1);
        }
        return toYYYYMMDD(targetDate);
      }
    }

    // Return null if no format matches
    return undefined;
  };

  const downloadDataAsCSV = () => {
    const data = window.scrapedElements;

    if (!data || data.length === 0) {
      console.error("Aucune donnée trouvée dans window.scrapedElements à télécharger.");
      return;
    }

    // Helper function to escape CSV fields
    const escapeCsvField = (field) => {
      const str = String(field == null ? "" : field);
      // If the field contains a comma, newline, or double quote, enclose it in double quotes.
      if (/[",\n]/.test(str)) {
        // Also, double up any existing double quotes.
        return `"${str.replace(/"/g, '""')}"`;
      }
      return str;
    };

    // Use the keys from the first object as headers
    const headers = Object.keys(data[0]);
    const csvHeader = headers.map(escapeCsvField).join(',');

    // Convert each object to a CSV row
    const csvRows = data.map(row =>
      headers.map(header => escapeCsvField(row[header])).join(',')
    );

    // Combine header and rows
    const csvContent = [csvHeader, ...csvRows].join('\n');

    // Create a Blob with the CSV content
    const blob = new Blob([csvContent], {
      type: 'text/csv;charset=utf-8;'
    });

    // Create a link element to trigger the download
    const link = document.createElement("a");
    if (link.download !== undefined) { // Check for browser support
      const url = URL.createObjectURL(blob);
      const timestamp = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
      link.setAttribute("href", url);
      link.setAttribute("download", `swile-data-${timestamp}.csv`);
      link.style.visibility = 'hidden';

      // Append, click, and remove the link
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);

      // Clean up the object URL
      URL.revokeObjectURL(url);
    }
  };


  /**
   * The list that will contain all the extracted elements.
   * Using a Set prevents duplicates.
   */
  const extractedElements = new Set();

  /**
   * Set to track already processed element IDs to avoid reprocessing
   */
  const processedIds = new Set();

  /**
   * Stop flag - set window.stopSwileExtraction = true to stop the script
   */
  window.stopSwileExtraction = false;

  /**
   * The class name of the elements to extract.
   */
  const className = "grid grid-cols-[1fr] items-center rounded-sm pb-8 antialiased outline-content-default dark:outline-content-default-dark -outline-offset-2 outline-2 has-[button.global-btn:focus-visible]:outline m-4 cursor-pointer hover:bg-background-screen-level0 hover:bg-opacity-60 dark:hover:bg-background-screen-level0-dark";

  let previousHeight = -1;
  let processedCount = 0;
  const startTime = Date.now();

  console.log("🚀 Extraction démarrée. Pour arrêter: window.stopSwileExtraction = true");

  while (true) {
    // Check stop flag
    if (window.stopSwileExtraction) {
      console.log("⛔ Arrêt demandé par l'utilisateur.");
      break;
    }
    // 1. Extract elements with the specified class name
    const elements = document.getElementsByClassName(className);

    // 2. Add the extracted elements to our list
    for (const element of elements) {
      // Check stop flag before processing each transaction
      if (window.stopSwileExtraction) {
        console.log("⛔ Arrêt demandé par l'utilisateur.");
        break;
      }

      // Ignore cancelled transactions
      if (element.querySelector(".line-through")) {
        continue;
      }

      // Check if it's a regularisation transaction
      const elementText = element.textContent?.trim();
      if (elementText.includes("Régularisation bancaire automatique")) {
        continue;
      }

      // Get div ID
      const div = element.getElementsByClassName("pointer-events-none col-start-1 col-end-2 row-start-1 p-nano")?.[0];
      const divId = div?.id;

      // Skip if already processed
      if (divId && processedIds.has(divId)) {
        continue;
      }

      // Mark as processed
      if (divId) {
        processedIds.add(divId);
      }

      // Get payee
      const payee = element.getElementsByClassName("antialiased m-0 text-content-default dark:text-content-default-dark [display:inherit] font-sans text-16 leading-6 [text-align:inherit]")?.[0]?.textContent?.trim();

      // Get amount
      const amountStr = element.getElementsByClassName("antialiased m-0 [display:inherit] whitespace-nowrap font-sans text-16 leading-6 [text-align:inherit] text-[--text-color] dark:text-[--text-color]")?.[0]?.textContent?.trim();
      const amountNumber = extractAmount(amountStr);

      // Get date
      const dateStr = element.getElementsByClassName("antialiased m-0 [display:inherit] font-sans text-14 leading-5 [text-align:inherit] text-content-subdued dark:text-content-subdued-dark")?.[0]?.textContent?.trim();
      const date = extractDate(dateStr);

      // Click to open modal and extract TR/CB details
      // Find the actual clickable button inside the element
      const button = element.querySelector('button.global-btn');
      if (!button) {
        console.warn(`⚠️ Bouton non trouvé pour ${payee}`);
        continue;
      }
      
      // Scroll into view and click the button
      button.scrollIntoView({ behavior: 'instant', block: 'center' });
      await new Promise(resolve => setTimeout(resolve, TIMING.SCROLL_INTO_VIEW_DELAY * 1000));
      
      button.click();
      
      // Small delay to let the click register
      await new Promise(resolve => setTimeout(resolve, TIMING.POST_CLICK_DELAY * 1000));
      
      // Wait for modal to appear AND contain the correct payee
      let modal = null;
      let attempts = 0;
      
      while (attempts < TIMING.MODAL_WAIT_MAX_ATTEMPTS) {
        const currentModal = document.querySelector('[role="dialog"]');
        if (currentModal) {
          // Check if the modal contains the correct payee to ensure it's the right one
          const modalText = currentModal.textContent || '';
          const normalizedPayee = payee.trim().toLowerCase();
          const normalizedModalText = modalText.toLowerCase();
          
          if (normalizedModalText.includes(normalizedPayee)) {
            modal = currentModal;
            break;
          }
        }
        await new Promise(resolve => setTimeout(resolve, TIMING.MODAL_WAIT_INTERVAL * 1000));
        attempts++;
      }

      let trAmount = null;
      let cbAmount = null;

      if (modal) {
        // Find all divs that contain account debit information
        // They have class "mb-8 flex" and contain the text " from "
        const allDivs = modal.querySelectorAll('div');
        
        for (const div of allDivs) {
          const text = div.textContent || '';
          
          // Check if this div contains " from " which indicates an account debit entry
          if (text.includes(' from ')) {
            const lowerText = text.toLowerCase();
            
            // Extract the amount - look for pattern like "-€25.00" or "-€0.03"
            const amountMatch = text.match(/[-−]€(\d+[.,]\d{2})/);
            
            if (amountMatch) {
              const amountStr = amountMatch[0].replace('−', '-'); // normalize dash
              const amount = extractAmount(amountStr);
              
              // Determine account type
              if (lowerText.includes('meal voucher') || lowerText.includes('titre')) {
                trAmount = amount;
              } else if (lowerText.includes('•') || lowerText.includes('card') || /\d{4}/.test(lowerText) || lowerText.includes(' bc')) {
                cbAmount = amount;
              }
            }
          }
        }
      }

      // Close modal with ESC
      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', keyCode: 27 }));
      
      // Wait for modal to actually close (check that it's gone)
      let closedAttempts = 0;
      while (document.querySelector('[role="dialog"]') && closedAttempts < TIMING.MODAL_CLOSE_MAX_ATTEMPTS) {
        await new Promise(resolve => setTimeout(resolve, TIMING.MODAL_CLOSE_CHECK_INTERVAL * 1000));
        closedAttempts++;
      }
      await new Promise(resolve => setTimeout(resolve, TIMING.POST_CLOSE_DELAY * 1000));

      extractedElements.add({
        payee: payee,
        amount: amountNumber,
        date: date,
        trAmount: trAmount,
        cbAmount: cbAmount,
        uniqueId: `${payee}|${date}|${amountNumber}|${divId}`,
      });

      // Log detailed extraction info
      console.log(`✅ ${payee} | ${date} | Total: ${amountNumber}€ | TR: ${trAmount}€ | CB: ${cbAmount}€`);

      processedCount++;
      if (processedCount % 10 === 0) {
        const elapsed = (Date.now() - startTime) / 1000;
        const avgTime = elapsed / processedCount;
        const totalExtracted = extractedElements.size;
        const eta = Math.round((avgTime * 10) / 60); // Next 10 transactions
        console.log(`Processed: ${processedCount} tx (${totalExtracted} distinct) | Elapsed time: ${Math.round(elapsed)}s | Speed: ${Math.round(avgTime)}s/tx`);
      }
    }

    // 3. Scroll to the bottom of the page
    window.scrollTo(0, document.body.scrollHeight);

    // Wait for a moment to let new content load
    await new Promise(resolve => setTimeout(resolve, TIMING.SCROLL_WAIT_DELAY * 1000));

    // 5. Stop if the scroll height hasn't changed, meaning we're at the bottom
    if (document.body.scrollHeight === previousHeight) {
      console.log("Deteced the end of the tx list");
      break;
    }

    const newElements = document.getElementsByClassName(className).length;
    console.log(`🔄 Scroll... ${newElements} transactions visibles au total`);
    previousHeight = document.body.scrollHeight;
  }

  // Make the list available globally and log it
  window.scrapedElements = Array.from(extractedElements);

  // Deduplicate on uniqueId
  window.scrapedElements = window.scrapedElements.filter((element, index, self) =>
    index === self.findIndex((t) => t.uniqueId === element.uniqueId)
  );

  // Get the total amount from swile
  const actualTotalAmount = document.getElementsByClassName("antialiased m-0 [display:inherit] font-sans text-14 leading-5 [text-align:inherit] text-content-subdued dark:text-content-subdued-dark")?.[0]?.textContent?.trim();
  const actualTotalAmountNumber = extractAmount(actualTotalAmount);

  // Get extracted total amount (meal vouchers only)
  const extractedTotalAmount = Math.round(window.scrapedElements.reduce((acc, element) => {
    // For all transactions: amount - cbAmount = meal vouchers only
    return acc + (element.amount - (element.cbAmount || 0));
  }, 0) * 100) / 100;


  console.log("Extraction finished.");
  console.log("Nb tx:", window.scrapedElements.length);
  console.log("Sum of the meal vouchers tx amounts:", extractedTotalAmount);
  console.log("Current meal vouchers balance:", actualTotalAmountNumber);

  if (extractedTotalAmount == actualTotalAmountNumber) {
    console.log(`%cData validation success: the sum of the meal vouchers tx amounts (${extractedTotalAmount}) equals the current meal vouchers balance (${actualTotalAmountNumber})`, "color: #529d00; font-weight: bold;");
  } else {
    console.log(`%cData validation failure: the sum of the meal vouchers tx amounts (${extractedTotalAmount}) differs from the current meal vouchers balance (${actualTotalAmountNumber})`, "color: #ff0000; font-weight: bold;");
  }

  downloadDataAsCSV();

})();
