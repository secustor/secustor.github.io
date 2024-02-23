
run-server:
	hugo server --disableFastRender

lint:
	markdownlint '**/*.md'

lint-fix:
	markdownlint --fix '**/*.md'
