module main

union Arg {
	i int
	ui u64
	f f64
	v voidptr
}

struct Button {
  arg Arg
mut:
  click u64
  mask u64
  button u64
  func fn (mut Arg) = fn(mut foo Arg){}
}

struct Client {
  name string
  mina f64 maxa f64
  x int y int w int h int
  oldx int oldy int oldw int oldh int
  basew int baseh int incw int inch int maxw int maxh int minw int minh int
  hintsvalid int
  bw int oldbw int
  tags u64
  isfixed int isfloating int isurgent int neverfocus int oldstate int isfullscreen int
  next &Client
  snext &Client

	//Monitor *mon;
	//Window win;
};

fn main() {}
