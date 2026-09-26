export interface SmsProvider {
  send(phone: string, message: string): Promise<void>;
}

/** Logs the code instead of sending a real text — used in dev/demo. */
class ConsoleSmsProvider implements SmsProvider {
  async send(phone: string, message: string): Promise<void> {
    console.log(`[sms:console] -> ${phone}: ${message}`);
  }
}

/**
 * Real provider slot. Set SMS_PROVIDER=twilio (or another) and fill this in
 * with that provider's SDK once credentials exist; the rest of the app only
 * ever talks to the SmsProvider interface.
 */
function buildProvider(): SmsProvider {
  const provider = process.env.SMS_PROVIDER ?? "console";
  switch (provider) {
    case "console":
      return new ConsoleSmsProvider();
    default:
      console.warn(`[sms] unknown SMS_PROVIDER "${provider}", falling back to console`);
      return new ConsoleSmsProvider();
  }
}

export const smsProvider: SmsProvider = buildProvider();
