package main

import (
	"context"
	"fmt"
	"time"

	glua "github.com/RyouZhang/go-lua"
)

// #cgo LDFLAGS: -static-libgcc -L/usr/local/lib -lluajit-5.1 -L${SRCDIR} -Wl,--whole-archive -lluabatteries -Wl,--no-whole-archive
import "C"

func main() {
	ts := time.Now()
	res, err := glua.NewAction().WithScript(`
		local iter = require 'iter'
		function sum(n)
			return iter.range(n):drop(n/10):take(n/10):reduce(iter.op.add, 0)
		end
	`).WithEntrypoint("sum").AddParam(10000000).Execute(context.Background())

	fmt.Println("cost:", time.Since(ts))
	fmt.Println(res, err)
}
