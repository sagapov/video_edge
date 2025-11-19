/**
 * Configuration Manager for Stream Provider URLs
 * Manages per-stream configurations with fallback to defaults
 */

export interface StreamProviders {
  urls: string[];
}

export interface StreamConfig {
  [streamKey: string]: StreamProviders;
}

export class ConfigManager {
  private defaultProviders: string[] = [];
  private streamConfigs: StreamConfig = {};

  /**
   * Set default provider URLs (used when no stream-specific config exists)
   */
  setDefaultProviders(urls: string[]): void {
    this.defaultProviders = urls;
    console.log(`[ConfigManager] Default providers updated: ${urls.join(', ')}`);
  }

  /**
   * Get default provider URLs
   */
  getDefaultProviders(): string[] {
    return [...this.defaultProviders];
  }

  /**
   * Set provider URLs for a specific stream
   */
  setStreamProviders(streamKey: string, urls: string[]): void {
    this.streamConfigs[streamKey] = { urls };
    console.log(`[ConfigManager] Stream '${streamKey}' providers updated: ${urls.join(', ')}`);
  }

  /**
   * Get provider URLs for a specific stream (with fallback to defaults)
   */
  getStreamProviders(streamKey: string): string[] {
    if (this.streamConfigs[streamKey]) {
      return [...this.streamConfigs[streamKey].urls];
    }
    return this.getDefaultProviders();
  }

  /**
   * Remove stream-specific configuration
   */
  removeStreamConfig(streamKey: string): boolean {
    if (this.streamConfigs[streamKey]) {
      delete this.streamConfigs[streamKey];
      console.log(`[ConfigManager] Stream '${streamKey}' configuration removed`);
      return true;
    }
    return false;
  }

  /**
   * Get all stream configurations
   */
  getAllConfigs(): { defaults: string[]; streams: StreamConfig } {
    return {
      defaults: this.getDefaultProviders(),
      streams: { ...this.streamConfigs }
    };
  }

  /**
   * Clear all configurations
   */
  clearAll(): void {
    this.defaultProviders = [];
    this.streamConfigs = {};
    console.log('[ConfigManager] All configurations cleared');
  }
}
