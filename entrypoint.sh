#!/bin/sh -l

set -e  # if a command fails it stops the execution
set -u  # script fails if trying to access to an undefined variable

echo "[+] Action start"
SOURCE_FILEPATH="${1}"
DESTINATION_GITHUB_USERNAME="${2}"
DESTINATION_REPOSITORY_NAME="${3}"
GITHUB_SERVER="${4}"
USER_EMAIL="${5}"
USER_NAME="${6}"
DESTINATION_REPOSITORY_USERNAME="${7}"
TARGET_BRANCH="${8}"
COMMIT_MESSAGE="${9}"
TARGET_DIRECTORY="${10}"
TARGET_FILENAME="${11}"
CREATE_TARGET_BRANCH_IF_NEEDED="${12}"
IMG_FOLDER="${13}"

if [ -z "$DESTINATION_REPOSITORY_USERNAME" ]
then
	DESTINATION_REPOSITORY_USERNAME="$DESTINATION_GITHUB_USERNAME"
fi

if [ -z "$USER_NAME" ]
then
	USER_NAME="$DESTINATION_GITHUB_USERNAME"
fi

# Verify that there (potentially) some access to the destination repository
# and set up git (with GIT_CMD variable) and GIT_CMD_REPOSITORY
if [ -n "${SSH_DEPLOY_KEY:=}" ]
then
	echo "[+] Using SSH_DEPLOY_KEY"

	# Inspired by https://github.com/leigholiver/commit-with-deploy-key/blob/main/entrypoint.sh , thanks!
	mkdir --parents "$HOME/.ssh"
	DEPLOY_KEY_FILE="$HOME/.ssh/deploy_key"
	echo "${SSH_DEPLOY_KEY}" > "$DEPLOY_KEY_FILE"
	chmod 600 "$DEPLOY_KEY_FILE"

	SSH_KNOWN_HOSTS_FILE="$HOME/.ssh/known_hosts"
	ssh-keyscan -H "$GITHUB_SERVER" > "$SSH_KNOWN_HOSTS_FILE"

	export GIT_SSH_COMMAND="ssh -i "$DEPLOY_KEY_FILE" -o UserKnownHostsFile=$SSH_KNOWN_HOSTS_FILE"

	GIT_CMD_REPOSITORY="git@$GITHUB_SERVER:$DESTINATION_REPOSITORY_USERNAME/$DESTINATION_REPOSITORY_NAME.git"

elif [ -n "${API_TOKEN_GITHUB:=}" ]
then
	echo "[+] Using API_TOKEN_GITHUB"
	GIT_CMD_REPOSITORY="https://$DESTINATION_REPOSITORY_USERNAME:$API_TOKEN_GITHUB@$GITHUB_SERVER/$DESTINATION_REPOSITORY_USERNAME/$DESTINATION_REPOSITORY_NAME.git"
else
	echo "::error::API_TOKEN_GITHUB and SSH_DEPLOY_KEY are empty. Please fill one (recommended the SSH_DEPLOY_KEY)"
	exit 1
fi


CLONE_DIR=$(mktemp -d)

echo "[+] Git version"
git --version

echo "[+] Enable git lfs"
git lfs install

echo "[+] Cloning destination git repository $DESTINATION_REPOSITORY_NAME"

# Setup git
git config --global user.email "$USER_EMAIL"
git config --global user.name "$USER_NAME"

# workaround for https://github.com/cpina/github-action-push-to-another-repository/issues/103
git config --global http.version HTTP/1.1

{
	git clone --single-branch --depth 1 --branch "$TARGET_BRANCH" "$GIT_CMD_REPOSITORY" "$CLONE_DIR"
} || {
    if [ "$CREATE_TARGET_BRANCH_IF_NEEDED" = "true" ]
    then
        # Default branch of the repository is cloned. Later on the required branch
	# will be created
        git clone --single-branch --depth 1 "$GIT_CMD_REPOSITORY" "$CLONE_DIR"
    else
        false
    fi
} || {
	echo "::error::Could not clone the destination repository. Command:"
	echo "::error::git clone --single-branch --branch $TARGET_BRANCH $GIT_CMD_REPOSITORY $CLONE_DIR"
	echo "::error::(Note that if they exist USER_NAME and API_TOKEN is redacted by GitHub)"
	echo "::error::Please verify that the target repository exist AND that it contains the destination branch name, and is accesible by the API_TOKEN_GITHUB OR SSH_DEPLOY_KEY"
	exit 1

}
ls -la "$CLONE_DIR"

if [ ! -d "$CLONE_DIR/$TARGET_DIRECTORY" ]
then
	echo "Creating $CLONE_DIR/$TARGET_DIRECTORY directory."
	mkdir -p $CLONE_DIR/$TARGET_DIRECTORY
fi
echo "[+] Copying contents of source repository folder $SOURCE_FILEPATH to folder $TARGET_DIRECTORY with the name $TARGET_FILENAME in git repo $DESTINATION_REPOSITORY_NAME"
cp -a "$SOURCE_FILEPATH" "$CLONE_DIR/$TARGET_DIRECTORY/$TARGET_FILENAME"
if [ "$IMG_FOLDER" != "IGNORE" ]
then
	cp -r "$IMG_FOLDER" "$CLONE_DIR/$TARGET_DIRECTORY"
fi
cd "$CLONE_DIR"

echo "[+] Files that will be pushed"
ls -la

ORIGIN_COMMIT="https://$GITHUB_SERVER/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
COMMIT_MESSAGE="${COMMIT_MESSAGE/ORIGIN_COMMIT/$ORIGIN_COMMIT}"
COMMIT_MESSAGE="${COMMIT_MESSAGE/\$GITHUB_REF/$GITHUB_REF}"

echo "[+] Set directory is safe ($CLONE_DIR)"
# Related to https://github.com/cpina/github-action-push-to-another-repository/issues/64
git config --global --add safe.directory "$CLONE_DIR"

if [ "$CREATE_TARGET_BRANCH_IF_NEEDED" = "true" ]
then
    echo "[+] Switch to the TARGET_BRANCH"
    # || true: if the $TARGET_BRANCH already existed in the destination repo:
    # it is already the current branch and it cannot be switched to
    # (it's not needed)
    # If the branch did not exist: it switches (creating) the branch
    git switch -c "$TARGET_BRANCH" || true
fi

echo "[+] Adding git commit"
git add .

echo "[+] git status:"
git status

echo "[+] git diff-index:"
# git diff-index : to avoid doing the git commit failing if there are no changes to be commit
git diff-index --quiet HEAD || git commit --message "$COMMIT_MESSAGE"

echo "[+] Pushing git commit"
# --set-upstream: sets de branch when pushing to a branch that does not exist
git push "$GIT_CMD_REPOSITORY" --set-upstream "$TARGET_BRANCH"
