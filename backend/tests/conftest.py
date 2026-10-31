import os
import shutil
import pytest

# Set testing environment flag immediately before any test or app module imports
os.environ["TESTING"] = "1"
os.environ["HF_HUB_OFFLINE"] = "1"

@pytest.fixture(scope="session", autouse=True)
def preserve_database_fixture():
    """Preserves populated SQLite database and uploaded face photos across destructive test runs like demo_reset."""
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    db_path = os.path.join(repo_root, "ghajini.db")
    backup_path = os.path.join(repo_root, ".ghajini_test_backup.db")
    uploads_dir = os.path.join(repo_root, "data", "uploads")
    backup_uploads = os.path.join(repo_root, "data", ".uploads_test_backup")

    if os.path.exists(db_path):
        shutil.copyfile(db_path, backup_path)
    if os.path.exists(uploads_dir):
        shutil.copytree(uploads_dir, backup_uploads, dirs_exist_ok=True)

    yield

    if os.path.exists(backup_path):
        shutil.copyfile(backup_path, db_path)
        try:
            os.remove(backup_path)
        except Exception:
            pass
    if os.path.exists(backup_uploads):
        shutil.copytree(backup_uploads, uploads_dir, dirs_exist_ok=True)
        try:
            shutil.rmtree(backup_uploads)
        except Exception:
            pass
