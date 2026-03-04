import chalk from 'chalk';

export type LogLevel = 'info' | 'success' | 'warn' | 'error' | 'skip' | 'debug';

export interface SkipReason {
  service: string;
  reason: string;
  suggestion?: string;
}

class Logger {
  private skippedServices: SkipReason[] = [];
  private seededCounts: Map<string, Map<string, number>> = new Map();
  private startTime: Date = new Date();
  private jsonMode = false;

  setJsonMode(enabled: boolean): void {
    this.jsonMode = enabled;
  }

  header(env: string): void {
    if (this.jsonMode) return;
    this.startTime = new Date();
    console.log();
    console.log(chalk.bold.cyan('╔══════════════════════════════════════════════════════════════╗'));
    console.log(chalk.bold.cyan('║') + chalk.bold.white('          LeaseBase Demo Data Seeder                          ') + chalk.bold.cyan('║'));
    console.log(chalk.bold.cyan('╚══════════════════════════════════════════════════════════════╝'));
    console.log();
    console.log(chalk.gray(`  Environment: `) + chalk.yellow.bold(env.toUpperCase()));
    console.log(chalk.gray(`  Started:     `) + chalk.white(this.startTime.toISOString()));
    console.log();
    console.log(chalk.gray('─'.repeat(64)));
    console.log();
  }

  serviceStart(service: string): void {
    if (this.jsonMode) return;
    console.log(chalk.bold.blue(`▸ ${service}`));
  }

  info(message: string): void {
    if (this.jsonMode) return;
    console.log(chalk.gray(`    ${message}`));
  }

  success(message: string): void {
    if (this.jsonMode) return;
    console.log(chalk.green(`    ✓ ${message}`));
  }

  warn(message: string): void {
    if (this.jsonMode) return;
    console.log(chalk.yellow(`    ⚠ ${message}`));
  }

  error(message: string): void {
    if (this.jsonMode) return;
    console.log(chalk.red(`    ✗ ${message}`));
  }

  skip(service: string, reason: string, suggestion?: string): void {
    this.skippedServices.push({ service, reason, suggestion });
    if (this.jsonMode) return;
    console.log(chalk.yellow(`    ⊘ SKIPPED: ${reason}`));
    if (suggestion) {
      console.log(chalk.gray(`      → ${suggestion}`));
    }
  }

  seeded(service: string, table: string, count: number): void {
    if (!this.seededCounts.has(service)) {
      this.seededCounts.set(service, new Map());
    }
    this.seededCounts.get(service)!.set(table, count);
    if (this.jsonMode) return;
    console.log(chalk.green(`    ✓ ${table}: ${count} rows`));
  }

  serviceComplete(service: string, status: 'SEEDED' | 'SKIPPED' | 'FAILED'): void {
    if (this.jsonMode) return;
    const icon = status === 'SEEDED' ? chalk.green('✓') : status === 'SKIPPED' ? chalk.yellow('⊘') : chalk.red('✗');
    const color = status === 'SEEDED' ? chalk.green : status === 'SKIPPED' ? chalk.yellow : chalk.red;
    console.log(`  ${icon} ${color(status)}`);
    console.log();
  }

  summary(): void {
    const endTime = new Date();
    const duration = (endTime.getTime() - this.startTime.getTime()) / 1000;

    if (this.jsonMode) {
      const result = {
        status: this.skippedServices.length === this.seededCounts.size ? 'all_skipped' : 'completed',
        duration_seconds: duration,
        seeded: Object.fromEntries(
          Array.from(this.seededCounts.entries()).map(([service, tables]) => [
            service,
            Object.fromEntries(tables.entries()),
          ])
        ),
        skipped: this.skippedServices,
      };
      console.log(JSON.stringify(result, null, 2));
      return;
    }

    console.log(chalk.gray('─'.repeat(64)));
    console.log();
    console.log(chalk.bold.cyan('Summary'));
    console.log();

    // Seeded services
    const seededCount = this.seededCounts.size;
    const skippedCount = this.skippedServices.length;
    const totalRows = Array.from(this.seededCounts.values()).reduce(
      (sum, tables) => sum + Array.from(tables.values()).reduce((s, c) => s + c, 0),
      0
    );

    console.log(chalk.green(`  ✓ Seeded:  ${seededCount} services (${totalRows} total rows)`));
    console.log(chalk.yellow(`  ⊘ Skipped: ${skippedCount} services`));

    if (this.skippedServices.length > 0) {
      console.log();
      console.log(chalk.yellow('  Skipped services:'));
      for (const skip of this.skippedServices) {
        console.log(chalk.gray(`    • ${skip.service}: ${skip.reason}`));
        if (skip.suggestion) {
          console.log(chalk.gray(`      → ${skip.suggestion}`));
        }
      }
    }

    console.log();
    console.log(chalk.gray(`  Duration: ${duration.toFixed(2)}s`));
    console.log(chalk.gray(`  Completed: ${endTime.toISOString()}`));
    console.log();
  }

  reset(): void {
    this.skippedServices = [];
    this.seededCounts = new Map();
  }
}

export const logger = new Logger();
