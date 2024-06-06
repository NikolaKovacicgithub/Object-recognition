# Compiler
CC = g++

# Compiler flags
CXXFLAGS = -I/usr/local/systemc-2.3.3/include -I/usr/local/include/opencv4 -ggdb3

# Linker flags
LDFLAGS = -L/usr/local/systemc-2.3.3/lib-linux64

# Libraries
LIBS = -lsystemc `pkg-config --cflags --libs opencv4`

# Source files
SRC = main.cpp cpu.cpp interconnect.cpp bram.cpp ip.cpp

# Object files
OBJ = $(SRC:.cpp=.o)

# Target executable
TARGET = output

all: $(TARGET)

$(TARGET): $(OBJ)
	@echo "Making output executable"
	@$(CC) $(CXXFLAGS) $(LDFLAGS) -o $@ $^ $(LIBS)

%.o: %.cpp
	@echo "Compiling $<"
	@$(CC) $(CXXFLAGS) -c $< -o $@

.PHONY: clean

clean:
	@rm -f $(OBJ) $(TARGET)
	@echo "Deleting all .o files and output executable"

