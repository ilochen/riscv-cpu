import {quicksortProgram,sortData} from './cpu-quicksort.js';
// Functional instruction trace grounded in CHIP.v. Cache response latency is illustrative.
const i32=x=>x|0;
export function encodeInstruction(i){
 const rd=i.rd||0,a=i.rs1||0,b=i.rs2||0,imm=i.imm||0;
 if(i.size===2)return ((imm>>5&1)<<12)|(rd<<7)|((imm&31)<<2)|1;
 if(i.op==='addi')return ((imm&4095)<<20)|(a<<15)|(rd<<7)|0x13;
 if(['add','sub','mul'].includes(i.op))return ((i.op==='sub'?32:i.op==='mul'?1:0)<<25)|(b<<20)|(a<<15)|(rd<<7)|0x33;
 if(i.op==='lw')return ((imm&4095)<<20)|(a<<15)|(2<<12)|(rd<<7)|3;
 if(i.op==='sw')return ((imm>>5&127)<<25)|(b<<20)|(a<<15)|(2<<12)|((imm&31)<<7)|0x23;
 if(i.op==='beq')return ((imm>>12&1)<<31)|((imm>>5&63)<<25)|(b<<20)|(a<<15)|((imm>>1&15)<<8)|((imm>>11&1)<<7)|0x63;
 return 0x13;
}
const I=(op,rd=0,rs1=0,rs2=0,imm=0,size=4)=>({op,rd,rs1,rs2,imm,size});
export function program(name='mixed'){
 const programs={
 mixed:[I('addi',1,0,0,5),I('addi',2,0,0,7),I('add',3,1,2),I('sw',0,0,3),I('lw',4,0),I('add',5,4,1),I('mul',6,5,2),I('beq',0,6,6,12),I('addi',7,0,0,99),I('addi',7,0,0,88),I('addi',8,8,0,3,2),I('add',9,6,8),I('sw',0,0,9,4)],
 forward:[I('addi',1,0,0,5),I('add',2,1,1),I('sub',3,2,1),I('add',4,3,2)],
 load:[I('lw',1,0),I('add',2,1,1),I('sw',0,0,2,4),I('lw',3,0,0,4)],
 branch:[I('addi',1,0,0,1),I('beq',0,1,1,12),I('addi',2,0,0,99),I('sw',0,0,1,4),I('addi',3,0,0,7)],
 cache:[I('addi',1,0,0,256),I('lw',2,1),I('addi',1,0,0,512),I('lw',3,1),I('addi',1,0,0,768),I('sw',0,1,2),I('lw',4,1)],
 compressed:[I('addi',1,1,0,5,2),I('addi',2,2,0,7,2),I('add',3,1,2),I('addi',3,3,0,-1,2),I('mul',4,3,2)]
 };let pc=0;
 return programs[name].map((i,id)=>{const p=pc;pc+=i.size;return {...i,id,pc:p,bits:encodeInstruction(i)>>>0,text:i.size===2?`c.addi x${i.rd}, ${i.imm}`:i.op==='addi'?`addi x${i.rd}, x${i.rs1}, ${i.imm}`:i.op==='lw'?`lw x${i.rd}, ${i.imm}(x${i.rs1})`:i.op==='sw'?`sw x${i.rs2}, ${i.imm}(x${i.rs1})`:i.op==='beq'?`beq x${i.rs1}, x${i.rs2}, +${i.imm}`:`${i.op} x${i.rd}, x${i.rs1}, x${i.rs2}`};});
}
export class DataCache{
 constructor(memory,latency=3){this.memory=memory;this.latency=latency;this.sets=Array.from({length:16},()=>[null,null]);this.pending=null;}
 install(address){const line=address>>>4,set=line&15,tag=line>>>4;const victim=this.sets[set][1];if(victim)victim.words.forEach((v,i)=>this.memory[((victim.tag<<4)|set)*16+i*4]=v);this.sets[set]=[{tag,words:Array.from({length:4},(_,i)=>this.memory[line*16+i*4]||0)},this.sets[set][0]];}
 access(address){const set=(address>>>4)&15,tag=address>>>8,word=(address>>>2)&3;
  let way=this.sets[set].findIndex(line=>line&&line.tag===tag);
  if(way<0){if(!this.pending)this.pending={address,left:this.latency,eviction:!!this.sets[set][1]};if(this.pending.left-->0)return {stall:true,set,tag,word,event:this.pending.eviction?'evict / refill':'refill',left:this.pending.left+1};this.install(address);this.pending=null;way=0;}
  if(way===1)this.sets[set].reverse();return {stall:false,set,tag,word,event:way===1?'way 1 hit → MRU':'way 0 hit',value:this.sets[set][0].words[word]};
 }
 store(address,value){const set=(address>>>4)&15;this.sets[set][0].words[(address>>>2)&3]=value;}
 visibleMemory(){const result={...this.memory};this.sets.forEach((ways,set)=>ways.forEach(line=>line?.words.forEach((v,i)=>result[((line.tag<<4)|set)*16+i*4]=v)));return result;}
}
export function simulateCPU(name='mixed',cold=false,options={}){
 const sorting=name==='quicksort',n=options.n||16,base=32;
 const instructions=sorting?quicksortProgram(n,base):program(name),lookup=new Map(instructions.map(i=>[i.pc,i])),memory=sorting?Object.fromEntries(sortData.map((v,i)=>[i*4,v])):{0:41,4:0,256:7,512:9,768:11},cache=new DataCache(memory),regs=Array(32).fill(0),icache=Array(16).fill(null),frames=[],retired=new Set(),mulReady=new Set();
 if(!cold){instructions.forEach(i=>icache[(i.pc>>>4)&15]=i.pc>>>8);cache.install(0);}
 let pc=0,ID=null,EX=null,MEM=null,WB=null,pendingI=null,serial=0;
 const writes=i=>i&&['addi','add','sub','mul','lw','slt','and','slli','jal','jalr'].includes(i.op)&&i.rd!==0;
 for(let cycle=0;cycle<(sorting?200000:150);cycle++){
  const raw=lookup.get(pc),fetch=raw?{...raw,id:serial}:null,events=[],forward=[];
  if(WB&&!retired.has(WB.id)){if(writes(WB)){regs[WB.rd]=WB.value;events.push(`WB: x${WB.rd} ← ${WB.value}`);}retired.add(WB.id);}
  let iStall=false;if(fetch&&icache[(pc>>>4)&15]!==pc>>>8){if(!pendingI)pendingI={left:3,pc};if(pendingI.left-->0)iStall=true;else{icache[(pc>>>4)&15]=pc>>>8;pendingI=null;}}
  const access=MEM&&['lw','sw'].includes(MEM.op)?cache.access(MEM.result>>>0):null;
  const memValue=MEM?(MEM.op==='lw'?access.value:MEM.result):0;
  let result=0,branch=false,exA=EX?.a||0,exB=EX?.b||0;
  if(['beq','bne','jalr'].includes(EX?.op)){
   const branchOperand=(rs,value)=>{if(writes(MEM)&&MEM.rd===rs){forward.push({from:'MEM',to:'branch',value:memValue});return memValue;}if(writes(WB)&&WB.rd===rs){forward.push({from:'WB',to:'branch',value:WB.value});return WB.value;}return value;};
   exA=branchOperand(EX.rs1,exA);exB=branchOperand(EX.rs2,exB);
  }
  if(EX){switch(EX.op){case 'addi':case 'lw':case 'sw':result=i32(exA+EX.imm);break;case 'add':result=i32(exA+exB);break;case 'sub':result=i32(exA-exB);break;case 'mul':result=Math.imul(exA,exB);break;case 'slli':result=exA<<EX.imm;break;case 'slt':result=+(exA<exB);break;case 'and':result=exA&exB;break;case 'jal':case 'jalr':result=EX.pc+EX.size;branch=EX.op==='jalr';break;case 'bne':branch=exA!==exB;break;case 'beq':branch=exA===exB;break;}}
  const mulStall=EX?.op==='mul'&&!mulReady.has(EX.id);if(mulStall)mulReady.add(EX.id);
  const globalStall=iStall||!!access?.stall||mulStall;
  const uses2=ID&&['add','sub','mul','sw','beq','bne','slt','and'].includes(ID.op);
  const loadStall=!!(ID&&EX?.op==='lw'&&EX.rd&&(EX.rd===ID.rs1||(uses2&&EX.rd===ID.rs2)));
  const operand=rs=>{if(!rs)return 0;if(writes(EX)&&EX.rd===rs){forward.push({from:'EX',to:'ID',value:result,reg:rs});return result;}if(writes(MEM)&&MEM.rd===rs){forward.push({from:'MEM',to:'ID',value:memValue,reg:rs});return memValue;}if(writes(WB)&&WB.rd===rs){forward.push({from:'WB',to:'ID',value:WB.value,reg:rs});return WB.value;}return regs[rs];};
  const decoded=ID?{...ID,a:operand(ID.rs1),b:uses2?operand(ID.rs2):0}:null;
  const flush=branch&&!globalStall,idJump=ID?.op==='jal'&&!globalStall&&!loadStall&&!flush,branchTarget=EX?.op==='jalr'?(exA+EX.imm)&~1:EX?EX.pc+EX.imm:0;
  if(globalStall)events.push(iStall?'Instruction-cache wait':access?.stall?'Data-cache wait':'Multiply: hold pipeline');
  else if(flush)events.push('Taken branch: flush IF/ID and ID/EX');else if(loadStall)events.push('Load-use: hold PC + IF/ID; inject ID/EX bubble');
  else if(idJump)events.push('JAL: redirect in decode; flush fetched instruction');
  else if(forward.length)events.push('Forward newest results into decode');
  const state={cycle,pc,idJump,mulStall:!!mulStall,mulPhase:EX?.op==='mul'?(mulStall?1:2):0,stages:[fetch,ID,EX,MEM,WB].map(i=>i?{...i}:null),regs:[...regs],result,exA,exB,access,icache:[...icache],cache:cache.sets.map(w=>w.map(x=>x?{tag:x.tag,words:[...x.words]}:null)),memory:cache.visibleMemory(),events,forward:globalStall?[]:forward,globalStall,loadStall:loadStall&&!globalStall,flush,branchTarget,memValue};frames.push(state);
  if(!fetch&&!ID&&!EX&&!MEM&&!WB)break;
  if(globalStall)continue;
  if(MEM?.op==='sw'){state.store={address:MEM.result>>>0,value:MEM.b,pc:MEM.pc};cache.store(MEM.result>>>0,MEM.b);events.push(`MEM: [${MEM.result}] ← ${MEM.b}`);}
  WB=MEM?{...MEM,value:memValue}:null;MEM=EX?{...EX,result}:null;
  if(flush){pc=branchTarget;ID=null;EX=null;}
  else if(loadStall){EX=null;}
  else if(idJump){pc=ID.pc+ID.imm;EX=decoded;ID=null;}
  else{EX=decoded;ID=fetch;if(fetch)serial++;pc=fetch?pc+fetch.size:pc;}
 }
 if(sorting&&frames.length>=200000)throw Error('Quicksort trace did not finish');
 return {sorting,n,base,instructions,frames,regs:[...regs],memory:cache.visibleMemory(),last:frames.length-1};
}
// Independent sequential architectural oracle for the supported demonstration subset.
export function runSequential(instructions,initial={0:41,4:0,256:7,512:9,768:11}){const regs=Array(32).fill(0),memory={...initial},lookup=new Map(instructions.map(i=>[i.pc,i]));let pc=0;
 for(let step=0;step<200000&&lookup.has(pc);step++){const i=lookup.get(pc),a=regs[i.rs1],b=regs[i.rs2];let value=0,next=pc+i.size;
  if(i.op==='addi')value=i32(a+i.imm);if(i.op==='add')value=i32(a+b);if(i.op==='sub')value=i32(a-b);if(i.op==='mul')value=Math.imul(a,b);if(i.op==='slt')value=+(a<b);if(i.op==='and')value=a&b;if(i.op==='slli')value=a<<i.imm;if(i.op==='lw')value=memory[i32(a+i.imm)]||0;if(i.op==='sw')memory[i32(a+i.imm)]=b;if(i.op==='beq'&&a===b)next=pc+i.imm;if(i.op==='bne'&&a!==b)next=pc+i.imm;if(i.op==='jal'||i.op==='jalr'){value=pc+i.size;next=i.op==='jal'?pc+i.imm:(a+i.imm)&~1;}if(i.rd)regs[i.rd]=value;regs[0]=0;pc=next;}
 return {regs,memory};}
