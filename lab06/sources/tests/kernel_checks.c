#include "../drivers/screen.h"
#include "../drivers/ports.h"
#define COM 0x3f8
static int passed, failed;
static volatile unsigned char *const v = (volatile unsigned char *)VIDEO_ADDRESS;
static void serial_init(void) {
    port_byte_out(COM+1,0); port_byte_out(COM+3,0x80);
    port_byte_out(COM,3); port_byte_out(COM+1,0);
    port_byte_out(COM+3,3); port_byte_out(COM+2,0xc7); port_byte_out(COM+4,0x0b);
}
static void serial(char *s) {
    while (*s) { while (!(port_byte_in(COM+5)&0x20)) {} port_byte_out(COM,*s++); }
}
static void check(int ok, char *name) {
    if (ok) { passed++; serial("PASS "); } else { failed++; serial("FAIL "); }
    serial(name); serial("\n");
}
static int cell(int n, unsigned char c, unsigned char a) { return v[2*n]==c && v[2*n+1]==a; }
static void checkpoint(char *name) {
    serial("SNAP "); serial(name); serial("\n");
    while (!(port_byte_in(COM+5)&1)) {} (void)port_byte_in(COM);
}
static unsigned int digest(void) {
    unsigned int d=0;
    for(int i=0;i<4000;i++) d=d*33+v[i];
    return d;
}
void main(void) {
    passed=0; failed=0;
    serial_init(); serial("LAB06 CHECKS START\n");
    for(int i=0;i<4000;i++) v[i]=0x55;
    clear_screen();
    int ok=1;
    for(int i=0;i<2000;i++) if(!cell(i,' ',0x0f)) ok=0;
    check(ok && get_cursor_offset()==0,"clear_all_2000_cells_cursor_zero");
    checkpoint("01-clear");
    check(get_offset(0,0)==0 && get_offset(79,24)==3998,"coordinate_formula");
    int offsets[]={0,2048,3998}; ok=1;
    for(int i=0;i<3;i++) { set_cursor_offset(offsets[i]); if(get_cursor_offset()!=offsets[i]) ok=0; }
    check(ok,"cursor_roundtrip_0_2048_3998");
    port_byte_out(0x3d4,14); int raw=port_byte_in(0x3d5)<<8;
    port_byte_out(0x3d4,15); raw|=port_byte_in(0x3d5);
    check(raw==1999,"ports_in_out_cursor_registers_1999");
    clear_screen(); print_char('A',3,2,0x1e);
    check(cell(163,'A',0x1e) && get_cursor_offset()==328,"explicit_position_and_attribute");
    print_char('B',-1,-1,0);
    check(cell(164,'B',0x0f) && get_cursor_offset()==330,"current_cursor_default_attribute");
    kprint("\nC");
    check(cell(240,'C',0x0f) && get_cursor_offset()==482,"newline_next_row_column_zero");
    print_char('Z',79,3,0);
    check(cell(319,'Z',0x0f) && get_cursor_offset()==640,"wrap_at_column_79");
    kprint_at("XY",10,5);
    check(cell(410,'X',0x0f)&&cell(411,'Y',0x0f)&&get_cursor_offset()==824,"kprint_at_string");
    kprint_attr("COLOR",0x2e);
    check(cell(412,'C',0x2e)&&cell(416,'R',0x2e),"string_color");
    checkpoint("02-print");
    for(int r=0;r<25;r++) for(int c=0;c<80;c++) {
        v[(r*80+c)*2]='A'+r; v[(r*80+c)*2+1]=0x10+(r%8);
    }
    set_cursor_offset(3998); print_char('\n',-1,-1,0);
    ok=1;
    for(int r=0;r<24;r++) for(int c=0;c<80;c++)
        if(!cell(r*80+c,'A'+r+1,0x10+((r+1)%8))) ok=0;
    for(int c=0;c<80;c++) if(!cell(24*80+c,' ',0x0f)) ok=0;
    check(ok && get_cursor_offset()==3840,"scroll_moves_24_rows_attributes_clears_last");
    checkpoint("03-scroll-attributes");
    clear_screen();
    for(int n=1;n<=30;n++) { char line[]="Line 00\n"; line[5]='0'+n/10; line[6]='0'+n%10; kprint(line); }
    ok=1;
    for(int r=0;r<24;r++) {
        int n=r+7; char expected[]="Line 00"; expected[5]='0'+n/10; expected[6]='0'+n%10;
        for(int c=0;c<7;c++) if(!cell(r*80+c,expected[c],0x0f)) ok=0;
        for(int c=7;c<80;c++) if(!cell(r*80+c,' ',0x0f)) ok=0;
    }
    for(int c=0;c<80;c++) if(!cell(1920+c,' ',0x0f)) ok=0;
    check(ok && get_cursor_offset()==3840,"long_text_30_lines_top_07_bottom_30");
    checkpoint("04-long-text");
    clear_screen(); kprint("Backspace test: ABCX\bD");
    check(cell(19,'D',0x0f)&&get_cursor_offset()==40,"backspace_replaces_X_with_D");
    set_cursor_offset(160); print_char('\b',-1,-1,0);
    check(cell(79,' ',0x0f)&&get_cursor_offset()==158,"backspace_crosses_row_boundary");
    set_cursor_offset(0); unsigned int before=digest(); print_char('\b',-1,-1,0);
    check(digest()==before&&get_cursor_offset()==0,"backspace_at_origin_no_underflow");
    before=digest(); int cursor=get_cursor_offset();
    print_char('!',80,0,0); print_char('!',0,25,0); print_char('!',-1,0,0);
    set_cursor_offset(-2); set_cursor_offset(1); set_cursor_offset(4000);
    check(digest()==before&&get_cursor_offset()==cursor,"invalid_coordinates_and_offsets_rejected");
    set_cursor_offset(320); kprint("All boundary checks completed."); checkpoint("05-backspace-bounds");
    if(failed==0 && passed==16) serial("SUMMARY PASS=16 FAIL=0\n");
    else serial("SUMMARY FAILED\n");
#ifdef PANIC_TEST
    clear_screen(); kprint("Panic test: execution must stop below.\n");
    serial("BEFORE_PANIC\n");
    kpanic("Expected laboratory panic");
    serial("AFTER_PANIC_UNEXPECTED\n");
#else
    clear_screen(); kprint("LR6: 16 checks passed. Normal boot restored.\n");
    serial("NORMAL_BOOT_COMPLETE\n");
#endif
    for(;;) __asm__ volatile("cli; hlt");
}
