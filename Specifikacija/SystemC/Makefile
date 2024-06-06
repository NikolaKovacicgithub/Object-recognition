# Compiler
CC = g++

# Compiler flags
CFLAGS = -I/usr/local/systemc-2.3.3/include -I/usr/local/include/opencv4 -ggdb3

# Linker flags
LDFLAGS = -L/usr/local/systemc-2.3.3/lib-linux64

# Libraries
LIBS = -lsystemc `pkg-config --cflags --libs opencv4`

# Source files
SRC = main.cpp

# Target executable
TARGET = main

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^ $(LIBS)

.PHONY: clean

clean:
	rm -f $(TARGET)

run: $(TARGET)
	./$(TARGET)

