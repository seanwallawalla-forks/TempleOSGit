#define MT_HOSE		1
#define MT_DROPLET	2
class MyMass:CMass
{
  I64 type;
  F64 radius;
};

#define ST_HOSE		1
class MySpring:CSpring
{
  I64 type;
};



	/* <1> <1> (image) */

	/* <2> <2> (image) */

	/* <3> <3> (image) */















/*  <4> (image) */

#define HOSE_RADIUS	3
#define LINK_SIZE	6
#define NOZZLE_START_Y	(GR_HEIGHT-15*FONT_HEIGHT)
#define NOZZLE_LEN	18
#define FAUCET_X	(5*HOSE_RADIUS)
#define FAUCET_Y	(GR_HEIGHT-12*FONT_HEIGHT)
#define GROUND_Y	(GR_HEIGHT-3*FONT_HEIGHT)
MyMass *faucet,*nozzle;
F64 nozzle_theta;

CMathODE *ode=NULL;
F64 start_up_timeout;

U0 DrawIt(CTask *,CDC *dc)
{
  Bool first;
  F64 dx,dy,d;
  I64  x1b,y1b,x2b,y2b,
	x1a,y1a,x2a,y2a;
  MyMass   *tmpm,*tmpm1;
  MySpring *tmps;
  CD3I32 poly[4];

  Sprite3(dc,0,GROUND_Y,0,__BIN_4);
  if (start_up_timeout>tS) {
    ode->drag_v2=0.01; //Let hose settle during start-up
    ode->drag_v3=0.0001;
    dc->color=RED;
    GrPrint(dc,(GR_WIDTH-FONT_WIDTH*6)>>1,GR_HEIGHT>>1,"Squirt");
    return;
  } else {
    ode->drag_v2=0.0005;
    ode->drag_v3=0.0000025;
  }

  tmpm=faucet;
  dc->color=BLACK;
  GrRect(dc,tmpm->x+8,tmpm->y,8,GROUND_Y-FAUCET_Y);
  Sprite3(dc,tmpm->x,tmpm->y,0,__BIN_1);
  dc->color=BLACK;
  GrCircle(dc,tmpm->x,tmpm->y,tmpm->radius);
  dc->color=GREEN;
  GrFloodFill(dc,tmpm->x,tmpm->y);

  tmpm=nozzle;
  tmpm1=nozzle->last;
  dx=tmpm->x-tmpm1->x;
  dy=tmpm->y-tmpm1->y;
  nozzle_theta=Wrap(Arg(dx,dy));
  Sprite3ZB(dc,tmpm->x,tmpm->y,0,__BIN_2,nozzle_theta);
  dc->color=BLACK;
  GrCircle(dc,tmpm->x,tmpm->y,tmpm->radius);
  dc->color=GREEN;
  GrFloodFill(dc,tmpm->x,tmpm->y);

  first=TRUE;
  tmpm=ode->next_mass;
  while (tmpm!=&ode->next_mass) {
    if (tmpm->type==MT_HOSE) {
      tmpm1=tmpm->last;
      dx=tmpm->x-tmpm1->x;
      dy=tmpm->y-tmpm1->y;
      d=HOSE_RADIUS/Max(Sqrt(dx*dx+dy*dy),0.001);
      dx*=d;
      dy*=d;
      x2a=tmpm->x-dy;
      y2a=tmpm->y+dx;
      x2b=tmpm->x+dy;
      y2b=tmpm->y-dx;

      if (first)
	first=FALSE;
      else {
	dc->color=GREEN;
	poly[0].x=x1a;
	poly[0].y=y1a;
	poly[0].z=0;
	poly[1].x=x2a;
	poly[1].y=y2a;
	poly[1].z=0;
	poly[2].x=x2b;
	poly[2].y=y2b;
	poly[2].z=0;
	poly[3].x=x1b;
	poly[3].y=y1b;
	poly[3].z=0;
	GrFillPoly3(dc,4,poly);
      }

      //Fill gaps
      GrLine(dc,x2a,y2a,x2b,y2b);

      x1a=x2a;
      y1a=y2a;
      x1b=x2b;
      y1b=y2b;
    } else if (tmpm->type==MT_DROPLET)
      Sprite3(dc,tmpm->x,tmpm->y,0,__BIN_3);
    tmpm=tmpm->next;
  }

  tmps=ode->next_spring;
  while (tmps!=&ode->next_spring) {
    if (tmps->type==ST_HOSE) {
      dx=tmps->end1->x-tmps->end2->x;
      dy=tmps->end1->y-tmps->end2->y;
      d=HOSE_RADIUS/Max(Sqrt(dx*dx+dy*dy),0.001);
      dx*=d;
      dy*=d;
      dc->color=BLACK;
      GrLine(dc,tmps->end1->x-dy,tmps->end1->y+dx,
	    tmps->end2->x-dy,tmps->end2->y+dx);
      GrLine(dc,tmps->end1->x+dy,tmps->end1->y-dx,
	    tmps->end2->x+dy,tmps->end2->y-dx);
    }
    tmps=tmps->next;
  }
}

U0 MyDerivative(CMathODE *ode,F64 t,COrder2D3 *state,COrder2D3 *DstateDt)
{//The forces due to springs and drag are
//automatically handled by the
  //ode code.  We can add new forces
  //here.
  no_warn t,state,DstateDt;
  MyMass *tmpm1=ode->next_mass;
  while (tmpm1!=&ode->next_mass) {
    if (tmpm1->type==MT_HOSE) {
      if (tmpm1->state->y+tmpm1->radius>GROUND_Y)
	tmpm1->DstateDt->DyDt-=Sqr(Sqr(tmpm1->state->y+
	      tmpm1->radius-GROUND_Y))*tmpm1->mass;
      else
	tmpm1->DstateDt->DyDt+=500*tmpm1->mass;
      if (tmpm1==nozzle || tmpm1==faucet) {
	tmpm1->DstateDt->DxDt=0;
	tmpm1->DstateDt->DyDt=0;
      }
    } else if (tmpm1->type==MT_DROPLET)
      tmpm1->DstateDt->DyDt=500*tmpm1->mass;
    tmpm1=tmpm1->next;
  }
}

MyMass *PlaceMass(I64 type,I64 x, I64 y,F64 r,
	F64 dx,F64 dy,F64 mass,CTask *mem_task)
{
  MyMass *tmpm=CAlloc(sizeof(MyMass),mem_task);
  tmpm->type=type;
  tmpm->mass=mass;
  tmpm->drag_profile_factor=250.0;
  tmpm->x=x;
  tmpm->y=y;
  tmpm->DxDt=dx;
  tmpm->DyDt=dy;
  tmpm->radius=r;
  QueIns(tmpm,ode->last_mass);
  return tmpm;
}

MySpring PlaceSpring(MyMass *tmpm1,MyMass *tmpm2)
{
  MySpring *tmps=CAlloc(sizeof(MySpring));
  tmps->end1=tmpm1;
  tmps->end2=tmpm2;
  tmps->const=20000;
  QueIns(tmps,ode->last_spring);
  return tmps;
}

U0 HoseNew()
{
  I64 i;
  MyMass *tmpm1=NULL,*tmpm;
  MySpring *tmps;
  for (i=FAUCET_X;i<GR_WIDTH;i+=LINK_SIZE) {
    tmpm=PlaceMass(MT_HOSE,i/2,GROUND_Y-HOSE_RADIUS,HOSE_RADIUS,0,0,1.0,Fs);
    if (tmpm1) {
      tmps=PlaceSpring(tmpm,tmpm1);
      tmps->rest_len=LINK_SIZE;
      tmps->type=ST_HOSE;
      nozzle=tmpm;
    } else
      faucet=tmpm;
    tmpm1=tmpm;
  }
  faucet->y=FAUCET_Y;
  nozzle->y=NOZZLE_START_Y;
  nozzle_theta=0;
}

U0 AnimateTask(I64)
{
  MyMass   *tmpm,*tmpm1;
  F64 dx,dy;
  while (TRUE) {
    dx=Cos(nozzle_theta);
    dy=Sin(nozzle_theta);
    PlaceMass(MT_DROPLET,
	  nozzle->x+NOZZLE_LEN*dx,nozzle->y+NOZZLE_LEN*dy,HOSE_RADIUS,
	  500*dx,500*dy,100.0,Fs->parent_task);
    if (Rand<0.05) //faucet drip
      PlaceMass(MT_DROPLET,
	    faucet->x,faucet->y,HOSE_RADIUS,
	    0,0,100.0,Fs->parent_task);

    tmpm=ode->next_mass;
    while (tmpm!=&ode->next_mass) {
      tmpm1=tmpm->next;
      if (tmpm->type==MT_DROPLET && tmpm->y+tmpm->radius>GROUND_Y) {
	QueRem(tmpm);
	Free(tmpm);
      }
      tmpm=tmpm1;
    }
    Refresh;
  }
}

#define NOZZLE_MOVE_STEPS	5
#define NOZZLE_MOVE		15.0
U0 MoveNozzleTaskX(I64 sign)
{
  I64 i;
  for (i=0;i<NOZZLE_MOVE_STEPS;i++) {
    nozzle->x=Clamp(nozzle->x+sign*NOZZLE_MOVE/NOZZLE_MOVE_STEPS,
	  HOSE_RADIUS*3,GR_WIDTH-HOSE_RADIUS*3);
    Refresh;
  }
}

U0 MoveNozzleTaskY(I64 sign)
{
  I64 i;
  for (i=0;i<NOZZLE_MOVE_STEPS;i++) {
    nozzle->y=Clamp(nozzle->y+sign*NOZZLE_MOVE/NOZZLE_MOVE_STEPS,
	  HOSE_RADIUS*3,GROUND_Y);
    Refresh;
  }
}

U0 Init()
{
  DocClear;
  "$BG,LTCYAN$%h*c",ToI64(GROUND_Y/FONT_HEIGHT),'\n';

  //Allow hose to settle.
  start_up_timeout=tS+0.5;

  ode=ODENew(0,5e-2,ODEF_HAS_MASSES);
  ode->derive=&MyDerivative;
  ode->acceleration_limit=5e3;

  HoseNew;
  QueIns(ode,Fs->last_ode);
}

U0 CleanUp()
{
  Refresh(NOZZLE_MOVE_STEPS); //Let nozzle move tasks die
  QueRem(ode);
  QueDel(&ode->next_mass,TRUE);
  QueDel(&ode->next_spring,TRUE);
  ODEDel(ode);
  DocClear;
}

U0 SongTask(I64)
{
  Fs->task_end_cb=&SndTaskEndCB;
  MusicSettingsRst;
  while (TRUE) {
    Play("5sDCDC4qA5DetDFFeDG4etA5EF4qG5eFC");
    Play("5sDCDC4qA5DetDFFeDG4etA5EF4qG5eFC");
    Play("5DCsG4A5G4AqBeBA5qEE4B5eC4B");
    Play("5DCsG4A5G4AqBeBA5qEE4B5eC4B");
  }
}

U0 Squirt()
{
  I64 sc;
  SettingsPush; //See [C:/Adam/TaskSettings.HC.Z,3] SettingsPush
  Fs->text_attr=YELLOW<<4+BLUE;
  Fs->song_task=Spawn(&SongTask,NULL,"Song",,Fs);
  AutoComplete;
  WinBorder;
  WinMax;
  DocCursor;

  MenuPush(
	"File {"
	"  Abort(,CH_SHIFT_ESC);"
	"  Exit(,CH_ESC);"
	"}"
	"Play {"
	"  Restart(,'\n');"
	"  Left(,,SC_CURSOR_LEFT);"
	"  Right(,,SC_CURSOR_RIGHT);"
	"  Up(,,SC_CURSOR_UP);"
	"  Down(,,SC_CURSOR_DOWN);"
	"}"
	);

  Init;
  Fs->animate_task=Spawn(&AnimateTask,NULL,"Animate",,Fs);
  Fs->draw_it=&DrawIt;

  try {
    while (TRUE) {
      switch (GetKey(&sc)) {
	case 0:
	  switch (sc.u8[0]) {
	    case SC_CURSOR_LEFT:
	      Spawn(&MoveNozzleTaskX,-1,"Move Nozzle",,Fs);
	      break;
	    case SC_CURSOR_RIGHT:
	      Spawn(&MoveNozzleTaskX,1,"Move Nozzle",,Fs);
	      break;
	    case SC_CURSOR_UP:
	      Spawn(&MoveNozzleTaskY,-1,"Move Nozzle",,Fs);
	      break;
	    case SC_CURSOR_DOWN:
	      Spawn(&MoveNozzleTaskY,1,"Move Nozzle",,Fs);
	      break;
	  }
	  break;
	case '\n':
	  CleanUp;
	  Init;
	  break;
	case CH_SHIFT_ESC:
	case CH_ESC:
	  goto sq_done;
      }
    }
sq_done: //Don't goto out of try
  } catch
    PutExcept;
  SettingsPop;
  CleanUp;
  MenuPop;
}

Squirt;
