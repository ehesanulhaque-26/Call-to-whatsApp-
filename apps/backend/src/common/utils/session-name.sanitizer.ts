/**
 * Session Name Sanitizer for OpenWA
 *
 * OpenWA only accepts session names containing:
 * - Letters (A-Z, a-z)
 * - Numbers (0-9)
 * - Hyphens (-)
 *
 * This utility sanitizes user-friendly session names to comply with OpenWA requirements.
 */

const logger = {
  log: (msg: string) => console.log(`[Sanitizer] ${msg}`),
};

/**
 * Sanitizes a session name for OpenWA compatibility
 *
 * Rules:
 * - Trim whitespace
 * - Replace spaces with hyphens
 * - Remove all characters except A-Z, a-z, 0-9, and hyphens
 * - Collapse repeated hyphens
 * - Remove leading/trailing hyphens
 * - Never return empty string (falls back to timestamp)
 *
 * @param name - The original session name (e.g., "Marketing Team", "Sales & Support")
 * @returns A sanitized name safe for OpenWA (e.g., "Marketing-Team", "Sales-Support")
 */
export function sanitizeSessionName(name: string | undefined | null): string {
  // Log when sanitizer is called
  logger.log(`sanitizeSessionName() invoked with: "${name}"`);

  // Handle null/undefined/empty input
  if (!name || name.trim() === '') {
    const result = `Session-${Date.now()}`;
    logger.log(`Empty input -> returning timestamp fallback: "${result}"`);
    return result;
  }

  // Step 1: Trim whitespace
  let sanitized = name.trim();

  // Step 2: Replace spaces with hyphens
  sanitized = sanitized.replace(/\s+/g, '-');

  // Step 3: Remove all characters except A-Z, a-z, 0-9, and hyphens
  sanitized = sanitized.replace(/[^A-Za-z0-9-]/g, '');

  // Step 4: Collapse repeated hyphens
  sanitized = sanitized.replace(/-+/g, '-');

  // Step 5: Remove leading/trailing hyphens
  sanitized = sanitized.replace(/^-+|-+$/g, '');

  // Step 6: If empty after sanitization, use timestamp fallback
  if (sanitized === '') {
    const result = `Session-${Date.now()}`;
    logger.log(`Empty after sanitization -> returning timestamp fallback: "${result}"`);
    return result;
  }

  logger.log(`Sanitization complete: "${name}" -> "${sanitized}"`);
  return sanitized;
}

/**
 * Examples:
 * - "Session 1" -> "Session-1"
 * - "Marketing Team" -> "Marketing-Team"
 * - "Sales & Support" -> "Sales-Support"
 * - "  My Session  " -> "My-Session"
 * - "Test@#$%Session" -> "TestSession"
 * - "---Test---" -> "Test"
 * - "" -> "Session-<timestamp>"
 */
