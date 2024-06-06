CC = g++
CFLAGS = -I/usr/local/include/opencv4 -ggdb3
LIBS = `pkg-config --cflags --libs opencv4 `
SRC = mainmanual.cpp
TARGET = main

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $^ $(LIBS)

.PHONY: clean

clean:
	rm -f $(TARGET)

run: $(TARGET)
	./$(TARGET)

