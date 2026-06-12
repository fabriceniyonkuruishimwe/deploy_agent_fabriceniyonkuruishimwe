# Student Attendance Tracker — Automated Project Bootstrap

## How to Run the Script

1. Clone the repository
git clone https://github.com/fabriceniyonkuruishimwe/deploy_agent_fabriceniyonkuruishimwe.git

2. Enter the project folder
cd deploy_agent_fabriceniyonkuruishimwe

3. Make the script executable
chmod +x setup_project.sh

4. Run the script
./setup_project.sh

5. Follow the prompts
- Enter a project identifier e.g. cohort_A
- Choose whether to update thresholds (y/n)
- If yes, enter Warning % and Failure %

6. Run the tracker
cd attendance_tracker_<your_input>
python3 attendance_checker.py

## How to Trigger the Archive Feature

Run the script and press Ctrl+C at any point after entering the project name.
The script will automatically:
- Bundle the incomplete project into attendance_tracker_<name>_archive.tar.gz
- Delete the incomplete directory
- Exit cleanly
