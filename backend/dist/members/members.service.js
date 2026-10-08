"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MembersService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
const serialize_1 = require("../common/serialize");
const fs_1 = require("fs");
const path_1 = __importDefault(require("path"));
let MembersService = class MembersService {
    constructor(p) {
        this.p = p;
    }
    async all(a) { return Promise.all((await this.p.member.findMany({ where: { adminId: a }, orderBy: { name: 'asc' } })).map(serialize_1.memberJson)); }
    async one(a, id) { const m = await this.p.member.findFirst({ where: { id: BigInt(id), adminId: a } }); if (!m)
        throw new common_1.NotFoundException('Member not found'); return (0, serialize_1.memberJson)(m); }
    async key(a, c = '', e) { if (!c.trim())
        return { taken: false }; const n = await this.p.member.count({ where: { adminId: a, keycard: { equals: c.trim() }, ...(e ? { NOT: { id: BigInt(e) } } : {}) } }); return { taken: n > 0 }; }
    body(a, b) { return { adminId: a, name: b.name, email: b.email || '', phone: b.phone || '', gender: b.gender, age: Number(b.age), plan: b.plan, durationMonths: Number(b.duration_months), fee: b.fee, joiningDate: new Date(b.joining_date), expiryDate: new Date(b.expiry_date), status: b.status || 'active', notesText: b.notes || '', keycard: (b.keycard || '').trim() || null, prKg: b.pr_kg || 0, createdAt: b.created_at ? new Date(b.created_at) : new Date() }; }
    async add(a, b) { try {
        return await this.p.$transaction(async (tx) => { const m = await tx.member.create({ data: this.body(a, b) }); await tx.finance.create({ data: { adminId: a, memberId: m.id, memberName: m.name, amount: b.fee, type: 'joining', plan: b.plan, description: 'Initial membership payment', method: b.method || 'Cash' } }); return { id: Number(m.id) }; });
    }
    catch (e) {
        if (e.code === 'P2002')
            throw new common_1.ConflictException('Keycard already in use');
        throw e;
    } }
    async update(a, id, b) { const old = await this.p.member.findFirst({ where: { id: BigInt(id), adminId: a } }); if (!old)
        throw new common_1.NotFoundException('Member not found'); const d = this.body(a, b); delete d.adminId; delete d.createdAt; try {
        await this.p.member.update({ where: { id: old.id }, data: d });
        return { success: true };
    }
    catch (e) {
        if (e.code === 'P2002')
            throw new common_1.ConflictException('Keycard already in use');
        throw e;
    } }
    async renew(a, id, b) { return this.p.$transaction(async (tx) => { const m = await tx.member.findFirst({ where: { id: BigInt(id), adminId: a } }); if (!m)
        throw new common_1.NotFoundException('Member not found'); const now = new Date(), start = m.expiryDate > now ? new Date(m.expiryDate) : now, exp = new Date(start); exp.setMonth(exp.getMonth() + Number(b.months)); await tx.member.update({ where: { id: m.id }, data: { plan: b.plan, durationMonths: Number(b.months), fee: b.amount, expiryDate: exp, status: 'active' } }); await tx.finance.create({ data: { adminId: a, memberId: m.id, memberName: m.name, amount: b.amount, type: 'renewal', plan: b.plan, description: `Membership renewal (${b.months} month)`, method: b.method || 'Cash' } }); return { success: true }; }); }
    async adjustment(a, id, b) { const m = await this.p.member.findFirst({ where: { id: BigInt(id), adminId: a } }); if (!m)
        throw new common_1.NotFoundException('Member not found'); await this.p.finance.create({ data: { adminId: a, memberId: m.id, memberName: m.name, amount: b.amount, type: 'adjustment', plan: m.plan, description: b.note || 'Payment adjustment', method: b.method || 'Cash' } }); return { success: true }; }
    async status(a, id, x) { const m = await this.p.member.findFirst({ where: { id: BigInt(id), adminId: a } }); if (!m)
        throw new common_1.NotFoundException('Member not found'); await this.p.member.update({ where: { id: m.id }, data: { status: x ? 'active' : 'inactive' } }); return { success: true }; }
    async pr(a, id, kg) { const m = await this.p.member.findFirst({ where: { id: BigInt(id), adminId: a } }); if (!m)
        throw new common_1.NotFoundException('Member not found'); await this.p.member.update({ where: { id: m.id }, data: { prKg: kg } }); return { success: true }; }
    async photo(a, id, f) { if (!f)
        throw new common_1.BadRequestException('Photo required'); const m = await this.p.member.findFirst({ where: { id: BigInt(id), adminId: a } }); if (!m) {
        await fs_1.promises.unlink(f.path).catch(() => { });
        throw new common_1.NotFoundException('Member not found');
    } await this.p.member.update({ where: { id: m.id }, data: { photoPath: f.filename } }); if (m.photoPath)
        await fs_1.promises.unlink(path_1.default.join(serialize_1.uploadsDir, path_1.default.basename(m.photoPath))).catch(() => { }); return { success: true }; }
    async del(a, id) { const m = await this.p.member.findFirst({ where: { id: BigInt(id), adminId: a } }); if (!m)
        return { deleted: 0 }; await this.p.member.delete({ where: { id: m.id } }); if (m.photoPath)
        await fs_1.promises.unlink(path_1.default.join(serialize_1.uploadsDir, path_1.default.basename(m.photoPath))).catch(() => { }); return { deleted: 1 }; }
    async clean(a) { const pics = await this.p.member.findMany({ where: { adminId: a, status: 'inactive' }, select: { photoPath: true } }); const r = await this.p.member.deleteMany({ where: { adminId: a, status: 'inactive' } }); for (const x of pics)
        if (x.photoPath)
            await fs_1.promises.unlink(path_1.default.join(serialize_1.uploadsDir, path_1.default.basename(x.photoPath))).catch(() => { }); return { deleted: r.count }; }
    async notes(a, id) { return (await this.p.note.findMany({ where: { adminId: a, memberId: BigInt(id) }, orderBy: { createdAt: 'desc' } })).map(x => ({ id: Number(x.id), member_id: Number(x.memberId), title: x.title, body: x.body || '', tags: x.tags || '', created_at: x.createdAt.toISOString() })); }
    async addNote(a, id, b) { const m = await this.p.member.findFirst({ where: { id: BigInt(id), adminId: a } }); if (!m)
        throw new common_1.NotFoundException('Member not found'); await this.p.note.create({ data: { adminId: a, memberId: m.id, title: b.title, body: b.body || '', tags: b.tags || '' } }); return { success: true }; }
};
exports.MembersService = MembersService;
exports.MembersService = MembersService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], MembersService);
//# sourceMappingURL=members.service.js.map