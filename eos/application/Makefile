CXX = g++
CXXFLAGS = -Wall `pkg-config --cflags opencv4`
LDFLAGS = `pkg-config --libs opencv4`

all: main

main: main.o
	$(CXX) -o $@ $^ $(LDFLAGS)

main.o: main.cpp
	$(CXX) $(CXXFLAGS) -c main.cpp -o main.o

clean:
	@echo "Cleaning build files..."
	rm -f *.o main

