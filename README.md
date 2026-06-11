# Linux Sysadmin Automation Kit (Mini Project 01)

A professional-grade, cross-platform server health monitoring script designed for system administrators. The tool monitors CPU usage, disk space partitions, RAM consumption, and service statuses, generating colorized console output and writing plain-text reports to log files.

## Project Structure
```text
sysadmin-toolkit/
├── bin/
│   └── health_check.sh       # The main automation script
├── config/
│   └── services.txt          # File containing services to monitor
├── logs/
│   └── health_check.log      # Log report output (automatically created)
├── .gitignore                # Excludes log files and IDE files
└── README.md                 # Project documentation
```

---

## Features

- **Automated Health Checks:** Monitors disk space, RAM usage, CPU load, and crucial system services.
- **Cross-Platform Compatibility:** Runs on native Linux platforms using standard commands (`free`, `systemctl`), and falls back to PowerShell/WIM interfaces automatically when executed in Git Bash under Windows.
- **Threshold Alerts:** Supports custom warning thresholds for both RAM and Disk usage.
- **Visual Feedback:** Color-coded status reporting in the terminal (Green for OK, Yellow for Warning, Red for Critical).
- **Structured Logging:** Appends a clean, formatted plain-text log summary of each run into `logs/health_check.log` with timestamps.

---

## Prerequisites

- **Linux:** Any standard distribution (Ubuntu, CentOS, Debian, etc.).
- **Windows:** Git Bash (MSYS2) with PowerShell installed (standard on Windows 10/11).

---

## Installation & Setup

1. **Verify Project Structure:**
   Ensure files are structured exactly as defined in the project layout.

2. **Configure Services to Monitor:**
   Open `config/services.txt` and add the services you want to monitor (one per line). For example:
   ```text
   sshd
   nginx
   docker
   cron
   ```

3. **Make the Script Executable:**
   In Git Bash or Linux terminal, run:
   ```bash
   chmod +x bin/health_check.sh
   ```

---

## Usage

Run the script directly from the project directory:

```bash
./bin/health_check.sh
```

### Command-Line Options

You can configure thresholds and logs dynamically:
```bash
./bin/health_check.sh [OPTIONS]

Options:
  -d <percent>    Disk usage warning threshold (default: 80)
  -m <percent>    RAM usage warning threshold (default: 80)
  -l <file_path>  Custom path to log file (default: logs/health_check.log)
  -s <file_path>  Custom path to services configuration file
  -h, --help      Show this help message and exit
```

#### Examples:
```bash
# Run with default settings (80% thresholds)
./bin/health_check.sh

# Run with stricter thresholds (50% RAM warning, 70% Disk warning)
./bin/health_check.sh -m 50 -d 70

# Save report to a custom log file location
./bin/health_check.sh -l /var/log/my_custom_health.log
```

---

## Scheduling the Script (Every Hour)

### 1. On Linux (using `cron`)
To automate the script to run hourly at the top of the hour:

1. Open your user crontab editor:
   ```bash
   crontab -e
   ```
2. Append the following line (replace with your absolute project directory path):
   ```cron
   0 * * * * /absolute/path/to/sysadmin-toolkit/bin/health_check.sh
   ```
3. Save and close the editor. The cron daemon will now execute the script every hour.

### 2. On Windows (using Git Bash & Task Scheduler)
To schedule this under Git Bash on Windows:

1. Open **Task Scheduler** (search for it in the Start menu).
2. Click **Create Basic Task...** in the right-hand panel.
3. **Name:** `Sysadmin Health Check`
4. **Trigger:** Select **Daily**, then complete the wizard. Once created, we will edit the task to repeat hourly.
5. **Action:** Select **Start a Program**.
6. **Program/script:** Enter the path to your Git Bash executable. Usually:
   `C:\Program Files\Git\bin\bash.exe`
7. **Add arguments (optional):** Enter:
   `--login -c "C:/DevOps/sysadmin-toolkit/bin/health_check.sh"`
8. Click **Finish**.
9. Double-click the newly created task in the list, go to the **Triggers** tab, click **Edit**, check the box for **Repeat task every:** and choose **1 hour**. Click **OK**.

---

## Pushing to a GitHub Repository

Follow these step-by-step instructions to create a GitHub repository and push your project:

1. **Create Repository on GitHub:**
   - Go to [GitHub](https://github.com/) and log in.
   - Click the **New** repository button in the top-left or top-right.
   - Set Repository Name to `sysadmin-toolkit`.
   - Leave it **Public** (or Private), and **DO NOT** initialize with a README, `.gitignore`, or license (since we have already created these files).
   - Click **Create repository**.

2. **Commit and Push using Git Bash:**
   Open Git Bash and run the following commands:
   ```bash
   # Make sure you are in the project folder
   cd /c/DevOps/sysadmin-toolkit

   # Stage all files
   git add .

   # Commit changes
   git commit -m "feat: complete server health monitoring automation kit"

   # Rename branch to main
   git branch -M main

   # Add your remote repository URL (replace USERNAME with your actual GitHub username)
   git remote add origin https://github.com/USERNAME/sysadmin-toolkit.git

   # Push to main branch
   git push -u origin main
   ```
