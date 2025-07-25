CC = gcc
CFLAGS = -Wall -Wextra -O2 -I./include
LDFLAGS = -lcurl -lcjson

SRC_DIR = src
OBJ_DIR = obj
BIN_DIR = bin
EXAMPLE_DIR = examples

SOURCES = $(wildcard $(SRC_DIR)/*.c)
OBJECTS = $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR)/%.o,$(SOURCES))

LIB_NAME = libwinccunified.a
LIB_PATH = $(BIN_DIR)/$(LIB_NAME)

EXAMPLES = basic_usage monitor_tags
EXAMPLE_BINS = $(patsubst %,$(BIN_DIR)/%,$(EXAMPLES))

.PHONY: all clean lib examples

all: lib examples

lib: $(LIB_PATH)

examples: $(EXAMPLE_BINS)

$(LIB_PATH): $(OBJECTS) | $(BIN_DIR)
	ar rcs $@ $^

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c | $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BIN_DIR)/%: $(EXAMPLE_DIR)/%.c $(LIB_PATH) | $(BIN_DIR)
	$(CC) $(CFLAGS) $< -o $@ -L$(BIN_DIR) -lwinccunified $(LDFLAGS)

$(OBJ_DIR) $(BIN_DIR):
	mkdir -p $@

clean:
	rm -rf $(OBJ_DIR) $(BIN_DIR)

install: lib
	install -d /usr/local/lib
	install -d /usr/local/include/winccunified
	install -m 644 $(LIB_PATH) /usr/local/lib/
	install -m 644 include/*.h /usr/local/include/winccunified/

.PHONY: test
test: examples
	@echo "Running basic usage example..."
	@if [ -f ../setenv.sh ]; then \
		. ../setenv.sh && $(BIN_DIR)/basic_usage; \
	else \
		echo "Please source setenv.sh to set environment variables"; \
		exit 1; \
	fi