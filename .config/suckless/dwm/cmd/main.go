package main

import "github.com/0persianman/x-go-binding/ui/x11"

func main() {
	win, err := x11.NewWindow()
	if err != nil {
		panic(err)
	}
	_ = win
}
