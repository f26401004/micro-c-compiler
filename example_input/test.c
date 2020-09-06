int add_six(int a) {
	return a + 6;
}

void main(){
	int c = 4;
	int b = add_six(c + 1) + 16;
	print(b);
	return;
}
