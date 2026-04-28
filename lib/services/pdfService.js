const PDFDocument = require('pdfkit');

const generateAttendancePDF = (dataList, stream, sessionInfo = {}) => {
    const doc = new PDFDocument({ 
        margin: 50, 
        size: 'A4',
        info: { Title: 'Attendance Report', Author: 'Hotspot Attendance System' } 
    });
    
    doc.pipe(stream);

    const courseName = sessionInfo.courseName || 'Untitled Course';
    const courseCode = sessionInfo.courseCode || null;
    const requiredConnectionMinutes = sessionInfo.requiredConnectionMinutes || 15;
    const now = new Date();

    // Compute stats
    let verified = 0;
    let pending = 0;
    dataList.forEach(user => {
        const connectedAt = new Date(user.connectedAt);
        const durationMinutes = Math.floor((now - connectedAt) / 60000);
        if (durationMinutes >= requiredConnectionMinutes) {
            verified++;
        } else {
            pending++;
        }
    });

    // ====== HEADER ======
    doc.fontSize(24).fillColor('#1a237e').font('Helvetica-Bold');
    doc.text(`${courseName} Attendance Report`, { align: 'center' });

    if (courseCode) {
        doc.fontSize(14).fillColor('#5a6e7c').font('Helvetica');
        doc.text(`Course Code: ${courseCode}`, { align: 'center' });
    }
    doc.moveDown(0.5);

    // ====== SESSION INFO ======
    doc.fontSize(12).fillColor('black').font('Helvetica-Bold');
    doc.text(`Course: ${courseName}`);
    doc.font('Helvetica-Bold').fontSize(11);
    doc.text(`Session Date: ${now.toISOString().substring(0, 16).replace('T', ' ')}`);
    doc.text(`Duration Required: ${requiredConnectionMinutes} min`);
    doc.moveDown(1.5);

    // ====== DAILY SNAPSHOT TABLE ======
    const startX = 50;
    let currentY = doc.y;
    const pageWidth = 500;
    const colWidths = [140, 90, 160, 40, 70]; // Name, Matricule, Email, Status, Time
    const totalWidth = colWidths.reduce((a, b) => a + b, 0);
    const scale = pageWidth / totalWidth;
    const scaledWidths = colWidths.map(w => w * scale);

    // Table header background
    doc.rect(startX, currentY, pageWidth, 20).fill('#1a237e');
    doc.fillColor('white').font('Helvetica-Bold').fontSize(10);
    const headers = ['Student Name', 'Matricule', 'Email', '', 'Joined'];
    let colX = startX;
    headers.forEach((h, i) => {
        doc.text(h, colX + 5, currentY + 5, { width: scaledWidths[i] - 10 });
        colX += scaledWidths[i];
    });
    currentY += 20;

    // Table rows
    doc.font('Helvetica').fontSize(9).fillColor('black');
    dataList.forEach((user, index) => {
        // Check page overflow
        if (currentY > 720) {
            doc.addPage();
            currentY = 50;
            // Redraw header on new page
            doc.rect(startX, currentY, pageWidth, 20).fill('#1a237e');
            doc.fillColor('white').font('Helvetica-Bold').fontSize(10);
            colX = startX;
            headers.forEach((h, i) => {
                doc.text(h, colX + 5, currentY + 5, { width: scaledWidths[i] - 10 });
                colX += scaledWidths[i];
            });
            currentY += 20;
            doc.font('Helvetica').fontSize(9).fillColor('black');
        }

        // Row background (alternating)
        if (index % 2 === 0) {
            doc.rect(startX, currentY, pageWidth, 18).fill('#f5f5f5');
        }

        const connectedAt = new Date(user.connectedAt);
        const durationMinutes = Math.floor((now - connectedAt) / 60000);
        const isVerified = durationMinutes >= requiredConnectionMinutes;

        // Status color
        const statusColor = isVerified ? '#2e7d32' : '#f57c00';

        colX = startX;
        doc.fillColor('black').text(user.username || 'N/A', colX + 5, currentY + 3, { width: scaledWidths[0] - 10 });
        colX += scaledWidths[0];
        doc.text(user.matricule || 'N/A', colX + 5, currentY + 3, { width: scaledWidths[1] - 10 });
        colX += scaledWidths[1];
        doc.text(user.email || 'N/A', colX + 5, currentY + 3, { width: scaledWidths[2] - 10 });
        colX += scaledWidths[2];
        
        // Status circle
        doc.circle(colX + scaledWidths[3] / 2, currentY + 9, 6).fill(statusColor);
        colX += scaledWidths[3];
        
        const timeStr = connectedAt.toTimeString().substring(0, 5);
        doc.text(timeStr, colX + 5, currentY + 3, { width: scaledWidths[4] - 10 });

        currentY += 18;
    });

    // Total row
    doc.rect(startX, currentY, pageWidth, 18).fill('#e8eaf6');
    doc.fillColor('#1a237e').font('Helvetica-Bold').fontSize(9);
    doc.text(`Total: ${dataList.length}`, startX + 5, currentY + 4);
    doc.moveDown(2);
    currentY = doc.y;

    // ====== SUMMARY SECTION ======
    if (currentY > 650) {
        doc.addPage();
        currentY = 50;
    }

    const summaryBoxY = currentY;
    doc.rect(startX, summaryBoxY, pageWidth, 60).fill('#f5f5f5');
    doc.fillColor('#1a237e').font('Helvetica-Bold').fontSize(18);
    
    const summaryItems = [
        { label: 'Total Students', value: dataList.length },
        { label: 'Verified', value: verified },
        { label: 'Pending', value: pending }
    ];
    
    const itemWidth = pageWidth / 3;
    summaryItems.forEach((item, i) => {
        const itemX = startX + i * itemWidth;
        doc.text(item.value.toString(), itemX, summaryBoxY + 10, { width: itemWidth, align: 'center' });
        doc.fontSize(10).fillColor('#5a6e7c').font('Helvetica');
        doc.text(item.label, itemX, summaryBoxY + 35, { width: itemWidth, align: 'center' });
        doc.fontSize(18).fillColor('#1a237e').font('Helvetica-Bold');
    });

    doc.moveDown(3);

    // ====== FOOTER ======
    doc.fontSize(10).fillColor('#9e9e9e').font('Helvetica-Oblique');
    doc.text('Generated by Hotspot Attendance System', { align: 'center' });

    doc.end();
};

module.exports = { generateAttendancePDF };

