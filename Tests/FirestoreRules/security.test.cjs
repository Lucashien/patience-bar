const { readFileSync } = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, collection, setDoc, getDoc, getDocs, updateDoc, deleteDoc, serverTimestamp, arrayUnion, runTransaction } = require('firebase/firestore');

(async () => {
  const env = await initializeTestEnvironment({projectId:'demo-patience-rules', firestore:{host:'127.0.0.1',port:8187,rules:readFileSync(require('node:path').join(__dirname, '../../firestore.rules'),'utf8')}});
  let passed = 0;
  const check = async (name, task) => { await task(); passed++; console.log('PASS '+name); };
  const db = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
  const owner=db('owner'), partner=db('partner'), outsider=db('outsider'), guest=db();
  const code='ABCDEFGH2345';
  const pair = client => doc(client,'couples',code);
  const user = (client,id) => doc(client,'couples',code,'users',id);
  const event = (client,id) => doc(client,'couples',code,'events',id);
  const newPair = {members:['owner'],inviteCode:code,createdAt:serverTimestamp()};
  try {
    await check('unauthenticated creation blocked',()=>assertFails(setDoc(pair(guest),newPair)));
    await check('cannot create a pair with someone else pre-enrolled',()=>assertFails(setDoc(pair(owner),{...newPair,members:['owner','outsider']})));
    await check('owner creates pair',()=>assertSucceeds(setDoc(pair(owner),newPair)));
    await check('owner creates own profile',()=>assertSucceeds(setDoc(user(owner,'owner'),{name:'測試甲',base:100})));
    await check('owner reads pair',()=>assertSucceeds(getDoc(pair(owner))));
    await check('outsider cannot read invitation or membership',()=>assertFails(getDoc(pair(outsider))));
    await check('outsider cannot list pairs',()=>assertFails(getDocs(collection(outsider,'couples'))));
    await check('owner cannot list all pairs',()=>assertFails(getDocs(collection(owner,'couples'))));
    await check('outsider cannot read profiles',()=>assertFails(getDoc(user(outsider,'owner'))));
    await check('outsider cannot read events',()=>assertFails(getDocs(collection(outsider,'couples',code,'events'))));
    await check('unauthenticated joining blocked',()=>assertFails(updateDoc(pair(guest),{members:arrayUnion('guest')})));
    await check('cannot replace owner while joining',()=>assertFails(updateDoc(pair(outsider),{members:['outsider','fake']})));
    await check('cannot add another person while joining',()=>assertFails(updateDoc(pair(partner),{members:arrayUnion('partner','outsider')})));
    await check('cannot alter invite code while joining',()=>assertFails(updateDoc(pair(partner),{members:arrayUnion('partner'),inviteCode:'WRONG'})));
    await check('owner cannot enroll someone else',()=>assertFails(updateDoc(pair(owner),{members:arrayUnion('outsider')})));
    await check('invited second member joins without reading pair',()=>assertSucceeds(updateDoc(pair(partner),{members:arrayUnion('partner')})));
    await check('partner can retry join',()=>assertSucceeds(updateDoc(pair(partner),{members:arrayUnion('partner')})));
    await check('partner reads joined pair',()=>assertSucceeds(getDoc(pair(partner))));
    await check('partner creates own profile',()=>assertSucceeds(setDoc(user(partner,'partner'),{name:'測試乙',base:100})));
    await check('third member blocked',()=>assertFails(updateDoc(pair(outsider),{members:arrayUnion('outsider')})));
    await check('member cannot replace partner',()=>assertFails(updateDoc(pair(owner),{members:['owner','outsider']})));
    await check('member cannot remove partner',()=>assertFails(updateDoc(pair(owner),{members:['owner']})));
    await check('member cannot change invite code',()=>assertFails(updateDoc(pair(owner),{inviteCode:'WRONG'})));
    await check('member cannot delete pair',()=>assertFails(deleteDoc(pair(owner))));
    await check('member reads partner profile',()=>assertSucceeds(getDoc(user(partner,'owner'))));
    await check('member cannot change partner name',()=>assertFails(updateDoc(user(partner,'owner'),{name:'spoofed'})));
    await check('cannot create nonmember profile',()=>assertFails(setDoc(user(owner,'outsider'),{name:'intruder',base:100})));
    await check('intended partner action and event transaction succeeds',()=>assertSucceeds(runTransaction(partner,async tx=>{
      await tx.get(user(partner,'owner'));
      tx.update(user(partner,'owner'),{base:90});
      tx.set(event(partner,'valid'),{actorId:'partner',targetId:'owner',type:'poke',delta:-10,createdAt:serverTimestamp()});
    })));
    await check('cannot forge event actor',()=>assertFails(setDoc(event(partner,'forged'),{actorId:'owner',targetId:'partner'})));
    await check('cannot target nonmember',()=>assertFails(setDoc(event(partner,'bad-target'),{actorId:'partner',targetId:'outsider'})));
    await check('events remain append-only',()=>assertFails(updateDoc(event(partner,'valid'),{delta:500})));
    await check('outsider still blocked after pairing',()=>assertFails(getDoc(user(outsider,'owner'))));
    await check('simultaneous joins admit only one partner',async()=>{
      const raceCode='ZXCVBNMA2345';
      await setDoc(doc(owner,'couples',raceCode),{members:['owner'],inviteCode:raceCode,createdAt:serverTimestamp()});
      const results=await Promise.allSettled([
        updateDoc(doc(partner,'couples',raceCode),{members:arrayUnion('partner')}),
        updateDoc(doc(outsider,'couples',raceCode),{members:arrayUnion('outsider')})
      ]);
      if(results.filter(r=>r.status==='fulfilled').length!==1) throw Error('Race admitted wrong number of partners');
      const final=await getDoc(doc(owner,'couples',raceCode));
      if(final.data().members.length!==2) throw Error('Race exceeded two members');
    });
    console.log(`ALL ${passed} SECURITY CHECKS PASSED`);
  } finally { await env.cleanup(); }
})().catch(err=>{console.error(err);process.exitCode=1;});
