
run-server:
	hugo server --disableFastRender

lint-fix:
	markdownlint --fix '**/*.md'
