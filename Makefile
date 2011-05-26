compile:
	coffee -c -o lib src/chat-client.coffee
	coffee -c -o bin src/chat-client-cli.coffee
	coffee -c -o bin src/chat-server.coffee

npm: compile
	npm publish

clean:
	rm -rf lib bin

.PHONY: compile npm clean
