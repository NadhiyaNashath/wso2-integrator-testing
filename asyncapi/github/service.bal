import ballerina/log;
import ballerinax/trigger.github as github;

configurable github:ListenerConfig listenerConfig = ?;

listener github:Listener githubListener = new (listenerConfig, 8090);

// ─── Issues ──────────────────────────────────────────────────────────────────

service github:IssuesService on githubListener {

    remote function onOpened(github:IssuesEvent payload) returns error? {
        log:printInfo("Issue opened",
                repo   = payload.repository.full_name,
                number = payload.issue.number,
                title  = payload.issue.title,
                author = payload.issue.user?.login ?: "unknown"
        );
    }

    remote function onClosed(github:IssuesEvent payload) returns error? {
        log:printInfo("Issue closed",
                repo   = payload.repository.full_name,
                number = payload.issue.number,
                title  = payload.issue.title
        );
    }

    remote function onReopened(github:IssuesEvent payload) returns error? {
        log:printInfo("Issue reopened",
                repo   = payload.repository.full_name,
                number = payload.issue.number,
                title  = payload.issue.title
        );
    }

    remote function onAssigned(github:IssuesEvent payload) returns error? {
        log:printInfo("Issue assigned",
                repo     = payload.repository.full_name,
                number   = payload.issue.number,
                assignee = payload.assignee?.login ?: "unknown"
        );
    }

    remote function onUnassigned(github:IssuesEvent payload) returns error? {
        log:printInfo("Issue unassigned",
                repo     = payload.repository.full_name,
                number   = payload.issue.number,
                assignee = payload.assignee?.login ?: "unknown"
        );
    }

    remote function onLabeled(github:IssuesEvent payload) returns error? {
        log:printInfo("Issue labeled",
                repo   = payload.repository.full_name,
                number = payload.issue.number,
                label  = payload.label?.name ?: "unknown"
        );
    }

    remote function onUnlabeled(github:IssuesEvent payload) returns error? {
        log:printInfo("Issue unlabeled",
                repo   = payload.repository.full_name,
                number = payload.issue.number,
                label  = payload.label?.name ?: "unknown"
        );
    }

    remote function onEdited(github:IssuesEvent payload) returns error? {
        log:printInfo("Issue edited",
                repo   = payload.repository.full_name,
                number = payload.issue.number,
                title  = payload.issue.title
        );
    }

    remote function onDeleted(github:IssuesEvent payload) returns error? {
        log:printInfo("Issue deleted",
                repo   = payload.repository.full_name,
                number = payload.issue.number,
                title  = payload.issue.title
        );
    }

    remote function onPinned(github:IssuesEvent payload) returns error? {
        log:printInfo("Issue pinned",
                repo   = payload.repository.full_name,
                number = payload.issue.number,
                title  = payload.issue.title
        );
    }

    remote function onUnpinned(github:IssuesEvent payload) returns error? {
        log:printInfo("Issue unpinned",
                repo   = payload.repository.full_name,
                number = payload.issue.number,
                title  = payload.issue.title
        );
    }

    remote function onMilestoned(github:IssuesEvent payload) returns error? {
        log:printInfo("Issue milestoned",
                repo   = payload.repository.full_name,
                number = payload.issue.number,
                title  = payload.issue.title
        );
    }

    remote function onDemilestoned(github:IssuesEvent payload) returns error? {
        log:printInfo("Issue demilestoned",
                repo   = payload.repository.full_name,
                number = payload.issue.number,
                title  = payload.issue.title
        );
    }

    remote function onTransferred(github:IssuesEvent payload) returns error? {
        log:printInfo("Issue transferred",
                repo   = payload.repository.full_name,
                number = payload.issue.number,
                title  = payload.issue.title
        );
    }

    remote function onTyped(github:IssuesEvent payload) returns error? {
        log:printInfo("Issue typed",
                repo   = payload.repository.full_name,
                number = payload.issue.number,
                title  = payload.issue.title
        );
    }

    remote function onUntyped(github:IssuesEvent payload) returns error? {
        log:printInfo("Issue untyped",
                repo   = payload.repository.full_name,
                number = payload.issue.number,
                title  = payload.issue.title
        );
    }

    remote function onLocked(github:IssuesEvent payload) returns error? {
        log:printInfo("Issue locked",
                repo   = payload.repository.full_name,
                number = payload.issue.number,
                title  = payload.issue.title
        );
    }

    remote function onUnlocked(github:IssuesEvent payload) returns error? {
        log:printInfo("Issue unlocked",
                repo   = payload.repository.full_name,
                number = payload.issue.number,
                title  = payload.issue.title
        );
    }
}

// ─── Issue Comments ──────────────────────────────────────────────────────────

service github:IssueCommentService on githubListener {

    remote function onCreated(github:IssueCommentEvent payload) returns error? {
        log:printInfo("Issue comment created",
                repo        = payload.repository.full_name,
                issueNumber = payload.issue.number,
                commentId   = payload.comment.id,
                author      = payload.comment.user?.login ?: "unknown"
        );
    }

    remote function onEdited(github:IssueCommentEvent payload) returns error? {
        log:printInfo("Issue comment edited",
                repo        = payload.repository.full_name,
                issueNumber = payload.issue.number,
                commentId   = payload.comment.id
        );
    }

    remote function onDeleted(github:IssueCommentEvent payload) returns error? {
        log:printInfo("Issue comment deleted",
                repo        = payload.repository.full_name,
                issueNumber = payload.issue.number,
                commentId   = payload.comment.id
        );
    }

    remote function onPinned(github:IssueCommentEvent payload) returns error? {
        log:printInfo("Issue comment pinned",
                repo        = payload.repository.full_name,
                issueNumber = payload.issue.number,
                commentId   = payload.comment.id
        );
    }

    remote function onUnpinned(github:IssueCommentEvent payload) returns error? {
        log:printInfo("Issue comment unpinned",
                repo        = payload.repository.full_name,
                issueNumber = payload.issue.number,
                commentId   = payload.comment.id
        );
    }
}

// ─── Pull Requests ────────────────────────────────────────────────────────────

service github:PullRequestService on githubListener {

    remote function onOpened(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request opened",
                repo   = payload.repository.full_name,
                number = payload.number,
                title  = payload.pull_request.title,
                author = payload.pull_request.user?.login ?: "unknown"
        );
    }

    remote function onClosed(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request closed",
                repo   = payload.repository.full_name,
                number = payload.number,
                title  = payload.pull_request.title,
                merged = payload.pull_request.merged ?: false
        );
    }

    remote function onReopened(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request reopened",
                repo   = payload.repository.full_name,
                number = payload.number,
                title  = payload.pull_request.title
        );
    }

    remote function onAssigned(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request assigned",
                repo     = payload.repository.full_name,
                number   = payload.number,
                assignee = payload.assignee.login
        );
    }

    remote function onUnassigned(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request unassigned",
                repo     = payload.repository.full_name,
                number   = payload.number,
                assignee = payload.assignee.login
        );
    }

    remote function onReviewRequested(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request review requested",
                repo     = payload.repository.full_name,
                number   = payload.number,
                reviewer = payload.requested_reviewer?.login ?: "unknown"
        );
    }

    remote function onReviewRequestRemoved(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request review request removed",
                repo     = payload.repository.full_name,
                number   = payload.number,
                reviewer = payload.requested_reviewer?.login ?: "unknown"
        );
    }

    remote function onLabeled(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request labeled",
                repo   = payload.repository.full_name,
                number = payload.number,
                label  = payload.label?.name ?: "unknown"
        );
    }

    remote function onUnlabeled(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request unlabeled",
                repo   = payload.repository.full_name,
                number = payload.number,
                label  = payload.label?.name ?: "unknown"
        );
    }

    remote function onEdited(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request edited",
                repo   = payload.repository.full_name,
                number = payload.number,
                title  = payload.pull_request.title
        );
    }

    remote function onEnqueued(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request enqueued",
                repo   = payload.repository.full_name,
                number = payload.number,
                title  = payload.pull_request.title
        );
    }

    remote function onDequeued(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request dequeued",
                repo   = payload.repository.full_name,
                number = payload.number,
                title  = payload.pull_request.title
        );
    }

    remote function onSynchronize(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request synchronize",
                repo   = payload.repository.full_name,
                number = payload.number,
                title  = payload.pull_request.title
        );
    }

    remote function onReadyForReview(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request ready for review",
                repo   = payload.repository.full_name,
                number = payload.number,
                title  = payload.pull_request.title
        );
    }

    remote function onAutoMergeEnabled(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request auto-merge enabled",
                repo   = payload.repository.full_name,
                number = payload.number,
                title  = payload.pull_request.title
        );
    }

    remote function onAutoMergeDisabled(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request auto-merge disabled",
                repo   = payload.repository.full_name,
                number = payload.number,
                title  = payload.pull_request.title
        );
    }

    remote function onLocked(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request locked",
                repo   = payload.repository.full_name,
                number = payload.number,
                title  = payload.pull_request.title
        );
    }

    remote function onUnlocked(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request unlocked",
                repo   = payload.repository.full_name,
                number = payload.number,
                title  = payload.pull_request.title
        );
    }

    remote function onMilestoned(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request milestoned",
                repo   = payload.repository.full_name,
                number = payload.number,
                title  = payload.pull_request.title
        );
    }

    remote function onDemilestoned(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request demilestoned",
                repo   = payload.repository.full_name,
                number = payload.number,
                title  = payload.pull_request.title
        );
    }

    remote function onConvertedToDraft(github:PullRequestEvent payload) returns error? {
        log:printInfo("Pull request converted to draft",
                repo   = payload.repository.full_name,
                number = payload.number,
                title  = payload.pull_request.title
        );
    }
}

// ─── Pull Request Reviews ─────────────────────────────────────────────────────

service github:PullRequestReviewService on githubListener {

    remote function onSubmitted(github:PullRequestReviewEvent payload) returns error? {
        log:printInfo("Pull request review submitted",
                repo     = payload.repository.full_name,
                prNumber = payload.pull_request.number,
                reviewer = payload.review.user?.login ?: "unknown",
                state    = payload.review.state
        );
    }

    remote function onEdited(github:PullRequestReviewEvent payload) returns error? {
        log:printInfo("Pull request review edited",
                repo     = payload.repository.full_name,
                prNumber = payload.pull_request.number,
                reviewer = payload.review.user?.login ?: "unknown"
        );
    }

    remote function onDismissed(github:PullRequestReviewEvent payload) returns error? {
        log:printInfo("Pull request review dismissed",
                repo     = payload.repository.full_name,
                prNumber = payload.pull_request.number,
                reviewer = payload.review.user?.login ?: "unknown"
        );
    }
}

// ─── Pull Request Review Comments ─────────────────────────────────────────────

service github:PullRequestReviewCommentService on githubListener {

    remote function onCreated(github:PullRequestReviewCommentEvent payload) returns error? {
        log:printInfo("Pull request review comment created",
                repo      = payload.repository.full_name,
                prNumber  = payload.pull_request.number,
                commentId = payload.comment.id,
                author    = payload.comment.user?.login ?: "unknown"
        );
    }

    remote function onEdited(github:PullRequestReviewCommentEvent payload) returns error? {
        log:printInfo("Pull request review comment edited",
                repo      = payload.repository.full_name,
                prNumber  = payload.pull_request.number,
                commentId = payload.comment.id
        );
    }

    remote function onDeleted(github:PullRequestReviewCommentEvent payload) returns error? {
        log:printInfo("Pull request review comment deleted",
                repo      = payload.repository.full_name,
                prNumber  = payload.pull_request.number,
                commentId = payload.comment.id
        );
    }
}

// ─── Push ─────────────────────────────────────────────────────────────────────

service github:PushService on githubListener {

    remote function onPush(github:PushEvent payload) returns error? {
        log:printInfo("Push received",
                repo    = payload.repository.full_name,
                ref     = payload.ref,
                commits = payload.commits.length(),
                pusher  = payload.pusher.name
        );
    }
}

// ─── Releases ─────────────────────────────────────────────────────────────────

service github:ReleaseService on githubListener {

    remote function onPublished(github:ReleaseEvent payload) returns error? {
        log:printInfo("Release published",
                repo = payload.repository.full_name,
                tag  = payload.release.tag_name,
                name = payload.release.name
        );
    }

    remote function onUnpublished(github:ReleaseEvent payload) returns error? {
        log:printInfo("Release unpublished",
                repo = payload.repository.full_name,
                tag  = payload.release.tag_name
        );
    }

    remote function onCreated(github:ReleaseEvent payload) returns error? {
        log:printInfo("Release created",
                repo = payload.repository.full_name,
                tag  = payload.release.tag_name
        );
    }

    remote function onEdited(github:ReleaseEvent payload) returns error? {
        log:printInfo("Release edited",
                repo = payload.repository.full_name,
                tag  = payload.release.tag_name
        );
    }

    remote function onDeleted(github:ReleaseEvent payload) returns error? {
        log:printInfo("Release deleted",
                repo = payload.repository.full_name,
                tag  = payload.release.tag_name
        );
    }

    remote function onPreReleased(github:ReleaseEvent payload) returns error? {
        log:printInfo("Pre-release published",
                repo = payload.repository.full_name,
                tag  = payload.release.tag_name
        );
    }

    remote function onPrereleased(github:ReleaseEvent payload) returns error? {
        log:printInfo("Pre-release published",
                repo = payload.repository.full_name,
                tag  = payload.release.tag_name
        );
    }

    remote function onReleased(github:ReleaseEvent payload) returns error? {
        log:printInfo("Release released",
                repo = payload.repository.full_name,
                tag  = payload.release.tag_name
        );
    }
}

// ─── Labels ───────────────────────────────────────────────────────────────────

service github:LabelService on githubListener {

    remote function onCreated(github:LabelEvent payload) returns error? {
        log:printInfo("Label created",
                repo  = payload.repository.full_name,
                label = payload.label.name,
                color = payload.label.color
        );
    }

    remote function onEdited(github:LabelEvent payload) returns error? {
        log:printInfo("Label edited",
                repo  = payload.repository.full_name,
                label = payload.label.name
        );
    }

    remote function onDeleted(github:LabelEvent payload) returns error? {
        log:printInfo("Label deleted",
                repo  = payload.repository.full_name,
                label = payload.label.name
        );
    }
}

// ─── Milestones ───────────────────────────────────────────────────────────────

service github:MilestoneService on githubListener {

    remote function onCreated(github:MilestoneEvent payload) returns error? {
        log:printInfo("Milestone created",
                repo   = payload.repository.full_name,
                title  = payload.milestone.title,
                number = payload.milestone.number
        );
    }

    remote function onEdited(github:MilestoneEvent payload) returns error? {
        log:printInfo("Milestone edited",
                repo   = payload.repository.full_name,
                title  = payload.milestone.title,
                number = payload.milestone.number
        );
    }

    remote function onDeleted(github:MilestoneEvent payload) returns error? {
        log:printInfo("Milestone deleted",
                repo   = payload.repository.full_name,
                title  = payload.milestone.title,
                number = payload.milestone.number
        );
    }

    remote function onClosed(github:MilestoneEvent payload) returns error? {
        log:printInfo("Milestone closed",
                repo   = payload.repository.full_name,
                title  = payload.milestone.title,
                number = payload.milestone.number
        );
    }

    remote function onOpened(github:MilestoneEvent payload) returns error? {
        log:printInfo("Milestone opened",
                repo   = payload.repository.full_name,
                title  = payload.milestone.title,
                number = payload.milestone.number
        );
    }
}
